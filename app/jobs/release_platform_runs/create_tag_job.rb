module ReleasePlatformRuns
  class CreateTagJob < ApplicationJob
    queue_as :high

    def perform(platform_run_id)
      ReleasePlatformRun.find(platform_run_id).create_tag!
    end
  end
end
