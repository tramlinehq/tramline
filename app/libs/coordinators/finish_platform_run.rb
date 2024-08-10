class Coordinators::FinishPlatformRun
  def self.call(release_platform_run)
    new(release_platform_run).call
  end

  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  def call
    with_lock do
      return unless release.on_track?
      release_platform_run.finish!

      if release.ready_to_be_finalized?
        Coordinators::StartFinalizingRelease.call(release, false)
      else
        release.partially_finish!
      end
    end

    ReleasePlatformRuns::CreateTagJob.perform_later(release_platform_run.id) if train.tag_platform_at_release_end?
    release_platform_run.event_stamp!(reason: :finished, kind: :success, data: {version: release_platform_run.version})
    app.refresh_external_app
    # TODO: [V2] notify properly
  end

  attr_reader :release_platform_run
  delegate :train, :with_lock, to: :release
  delegate :release, :app, to: :release_platform_run
end
