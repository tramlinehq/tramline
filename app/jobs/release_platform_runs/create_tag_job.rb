class ReleasePlatformRuns::CreateTagJob < ApplicationJob
  queue_as :high

  def perform(platform_run_id)
    run = ReleasePlatformRun.find(platform_run_id)
    run.create_tag!
  end
end
