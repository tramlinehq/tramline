class Coordinators::SoakPeriod::Extend
  def self.call(beta_soak, additional_hours, who)
    return unless beta_soak
    new(beta_soak, additional_hours, who).call
  end

  def initialize(beta_soak, additional_hours, who)
    @beta_soak = beta_soak
    @release = beta_soak.release
    @additional_hours = additional_hours.to_i
    @who = who
  end

  def call
    return unless release.active?
    return if additional_hours <= 0

    beta_soak.with_lock do
      return if beta_soak.ended_at.present? || beta_soak.expired?
      beta_soak.update!(period_hours: beta_soak.period_hours + additional_hours)
    end

    beta_soak.reload
    event_stamp!
    notify!
  end

  private

  attr_reader :release, :additional_hours, :who, :beta_soak

  def event_stamp!
    new_end_time_display = beta_soak.end_time.in_time_zone(release.app.timezone).strftime("%Y-%m-%d %H:%M %Z")
    beta_soak.event_stamp!(
      reason: :beta_soak_extended,
      kind: :notice,
      data: {
        additional_hours: additional_hours,
        new_end_time: new_end_time_display,
        extended_by: who.id
      }
    )
  end

  def notify!
    beta_soak.notify!("Soak period was extended!", :soak_period_extended, beta_soak.notification_params)
  end
end
