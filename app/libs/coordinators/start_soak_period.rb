class Coordinators::StartSoakPeriod
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    return unless release.soak_period_enabled?
    return if release.soak_started_at.present?

    # Check if any platform run has a successful beta release
    return unless release.release_platform_runs.any? { |rpr| rpr.latest_beta_release&.available? }

    release.start_soak_period!
  end

  private

  attr_reader :release
end
