class Coordinators::FinalizePlatformRun
  def self.call(release_platform_run)
    new(release_platform_run).call
  end

  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  def call
    with_lock do
      return unless release_platform_run.concluded?
      release_platform_run.finish!
    end

    release_platform_run.event_stamp!(
      reason: :finished,
      kind: :success,
      data: {version: release_platform_run.release_version}
    )
  end

  attr_reader :release_platform_run
  delegate :with_lock, to: :release_platform_run
end
