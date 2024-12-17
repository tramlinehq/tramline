module ReleasePlatformRuns
  class CreateTagJob < ApplicationJob
    queue_as :high

    def perform(platform_run_id, commit_id)
      commit = Commit.find(commit_id)
      ReleasePlatformRun.find(platform_run_id).create_tag!(commit)
    end
  end
end
