class Coordinators::AttachBuildJob < ApplicationJob
  HANDLED_EXCEPTION = Installations::Error
  sidekiq_options queue: :high, retry: 15

  sidekiq_retry_in do |count, ex|
    if artifact_not_found?(ex)
      backoff_in(attempt: count + 1, period: :seconds, type: :static, factor: 30).to_i
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    # If we don't find any artifact for the workflow after retrying,
    # we try to find the build in stores directly later
    if artifact_not_found?(ex)
      workflow_run_id = msg["args"].first
      workflow_run = WorkflowRun.find(workflow_run_id)
      workflow_run.build.mark_available_without_artifact!
      Signal.build_is_available!(workflow_run_id)
    end
  end

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    release_platform_run = workflow_run.release_platform_run
    return unless release_platform_run.on_track?

    # Attempt to attach artifact only if platform is android
    if release_platform_run.android?
      # raises Installations::Error if artifact is not found
      workflow_run.build.attach_artifact!
    elsif release_platform_run.ios?
      # There are only two cases for platform - android/ios, keeping it elsif for clarity
      # We don't handle uploads for ios (yet?)
      workflow_run.build.mark_available_without_artifact!
    end

    Signal.build_is_available!(workflow_run_id)
  rescue => ex
    raise ex if artifact_not_found?(ex) # re-raise if artifact is not found so we can retry a few times
    elog(ex, level: :error)
    workflow_run&.triggering_release&.fail!
  end

  def self.artifact_not_found?(ex) = ex.is_a?(HANDLED_EXCEPTION) && ex.reason == :artifact_not_found

  delegate :artifact_not_found?, to: self
end
