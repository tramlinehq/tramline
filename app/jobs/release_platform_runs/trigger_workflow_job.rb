module ReleasePlatformRuns
  class TriggerWorkflowJob < ApplicationJob
    queue_as :high

    def perform(platform_run_id, commit_id)
      platform_run = ReleasePlatformRun.find(platform_run_id)
      commit = Commit.find(commit_id)
      Coordinators::CreateBetaRelease.trigger_workflows(platform_run, commit)
    end
  end
end
