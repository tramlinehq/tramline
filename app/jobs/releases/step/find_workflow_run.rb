# Branch created -> step-run is created/on_track
# find workflow for triplet -> step-run goes to ci_started
# find workflow fails 3 times -> workflow is triggered -> ci_triggered
# find the triggered workflow again -> step_run goes to ci_started
# find the triggered workflow fails -> but does not retrigger because it was already triggered before
class Releases::Step::FindWorkflowRun
  include Sidekiq::Job

  class WorkflowRunNotFound < StandardError; end

  queue_as :high
  sidekiq_options retry: 2

  sidekiq_retry_in do |count, exception|
    if exception.is_a?(Releases::Step::FindWorkflowRun::WorkflowRunNotFound)
      10 * (count + 1)
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if ex.is_a?(Releases::Step::FindWorkflowRun::WorkflowRunNotFound)
      step_run = Releases::Step::Run.find(msg["args"].first)

      if step_run.may_ci_trigger?
        step_run.trigger_workflow!
      else
        # FIXME: tag the step run in an inconsistent state -- ci not found
      end
    end
  end

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    workflow_run = step_run.find_workflow_run&.slice(:id, :html_url)

    if workflow_run.present?
      step_run.start_ci!(workflow_run[:id], workflow_run[:html_url])
    else
      raise WorkflowRunNotFound
    end
  rescue => e
    Sentry.capture_exception(e)
    raise
  end
end
