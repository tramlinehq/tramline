class Coordinators::SoakPeriod::Start
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    return unless release.soak_period_enabled?
    return if release.beta_soak&.present?
    # Check if any platform run has a successful beta release
    return unless release.release_platform_runs.any? { |rpr| rpr.latest_beta_release&.present? }

    beta_soak = release.create_beta_soak!(started_at: Time.current, period_hours: release.train.soak_period_hours)
    event_stamp!(beta_soak)
    Coordinators::SoakPeriodCompletionJob.perform_in(beta_soak.period_hours.hours, beta_soak.id)
  end

  private

  attr_reader :release

  def event_stamp!(beta_soak)
    ends_at = beta_soak.end_time.in_time_zone(release.app.timezone).strftime("%Y-%m-%d %H:%M %Z")
    beta_soak.event_stamp!(reason: :beta_soak_started, kind: :notice, data: {ends_at: ends_at})
  end
end
