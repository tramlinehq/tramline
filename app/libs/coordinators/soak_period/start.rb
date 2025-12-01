class Coordinators::SoakPeriod::Start
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
    return unless release.release_platform_runs.any? { |rpr| rpr.latest_beta_release&.present? }

    release.with_lock do
      return if release.soak_started_at.present?

      release.update!(
        soak_started_at: Time.current,
        soak_period_hours: release.train.soak_period_hours
      )
      release.event_stamp!(
        reason: :soak_period_started,
        kind: :notice,
        data: {ends_at: soak_end_time_display}
      )

      Coordinators::SoakPeriodCompletionJob.perform_in(release.soak_period_hours.hours, release.id)
    end
  end

  private

  attr_reader :release

  def soak_end_time_display
    soak_end_time = release.soak_started_at + release.soak_period_hours.hours
    soak_end_time.in_time_zone(release.app.timezone).strftime("%Y-%m-%d %H:%M %Z")
  end
end
