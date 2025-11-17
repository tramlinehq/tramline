class Coordinators::SoakPeriod::Extend
  def self.call(release, additional_hours, who)
    new(release, additional_hours, who).call
  end

  def initialize(release, additional_hours, who)
    @release = release
    @additional_hours = additional_hours
    @who = who
  end

  def call
    return false unless release.active?
    return false unless soak_period_active?
    return false unless who == release.release_pilot
    return false if additional_hours.to_i <= 0

    # Move soak_started_at forward to extend the soak_end_time
    release.update!(soak_started_at: release.soak_started_at + additional_hours.hours)
    release.event_stamp!(
      reason: :soak_period_extended,
      kind: :notice,
      data: {
        additional_hours: additional_hours,
        new_end_time: new_end_time_display,
        extended_by: who.id
      }
    )
    true
  end

  private

  attr_reader :release, :additional_hours, :who

  def soak_period_active?
    release.soak_started_at.present? && !soak_period_completed?
  end

  def soak_period_completed?
    return false if release.soak_started_at.blank?
    soak_end_time = release.soak_started_at + release.soak_period_hours.hours
    Time.current >= soak_end_time
  end

  def new_end_time_display
    new_end_time = release.soak_started_at + additional_hours.hours + release.soak_period_hours.hours
    new_end_time.in_time_zone(release.app.timezone).strftime("%Y-%m-%d %H:%M %Z")
  end
end
