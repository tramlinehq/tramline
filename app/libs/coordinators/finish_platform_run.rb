class Coordinators::FinishPlatformRun
  def self.call(release_platform_run)
    new(release_platform_run).call
  end

  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  def call
    with_lock do
      return unless release.active?
      release_platform_run.finish!

      if release.ready_to_be_finalized?
        release.start_post_release_phase!
      else
        release.partially_finish!
      end
    end

    RefreshPlatformBreakdownJob.perform_async(release_platform_run.id)
    ReleasePlatformRuns::CreateTagJob.perform_async(release_platform_run.id, last_commit.id) if train.tag_platform_at_release_end?
    release_platform_run.event_stamp!(reason: :finished, kind: :success, data: {version: release_platform_run.release_version})
    app.refresh_external_app
    FinalizeReleaseJob.perform_async(release.id)
  end

  attr_reader :release_platform_run
  delegate :train, :with_lock, to: :release
  delegate :release, :app, :last_commit, to: :release_platform_run
end
