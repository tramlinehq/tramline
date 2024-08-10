class Coordinators::StopRelease
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    with_lock do
      release.stop!
      release.release_platform_runs.each(&:stop!)
    end

    release.update_train_version! if release.stopped_after_partial_finish?
    release.event_stamp!(reason: :stopped, kind: :notice, data: {version: release.release_version})
    release.notify!("Release has stopped!", :release_stopped, release.notification_params)
  end

  attr_reader :release
  delegate :with_lock, to: :release
end
