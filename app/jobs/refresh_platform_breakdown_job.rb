class RefreshPlatformBreakdownJob < ApplicationJob
  def perform(release_platform_run_id)
    release_platform_run = ReleasePlatformRun.find(release_platform_run_id)
    Queries::PlatformBreakdown.warm(release_platform_run.id)
  end
end
