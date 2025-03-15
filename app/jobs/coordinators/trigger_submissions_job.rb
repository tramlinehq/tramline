class Coordinators::TriggerSubmissionsJob < ApplicationJob
  sidekiq_options queue: :high

  def perform(workflow_run_id)
    workflow_run = WorkflowRun.find(workflow_run_id)
    release_platform_run = workflow_run.release_platform_run

    if workflow_run.release_candidate? && release_platform_run.hotfix?
      Coordinators::StartProductionRelease.call(release_platform_run, workflow_run.build.id)
    end

    workflow_run.triggering_release.trigger_submissions!
  end
end
