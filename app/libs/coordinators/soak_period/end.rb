class Coordinators::SoakPeriod::End
  def self.call(release, who)
    new(release, who).call
  end

  def initialize(release, who)
    @release = release
    @who = who
  end

  def call
    release.with_lock do
      return false unless release.active?
      return false unless soak_period_active?
      # Record when the soak period was manually ended
      release.update!(soak_ended_at: Time.current)
    end

    release.event_stamp!(reason: :soak_period_ended_early, kind: :notice, data: { ended_by: who.id })
    Coordinators::Signals.continue_after_soak_period!(release)

    true
  end

  private

  attr_reader :release, :who

  def soak_period_active?
    release.soak_started_at.present? && !soak_period_completed?
  end

  def soak_period_completed?
    return false if release.soak_started_at.blank?
    soak_end_time = release.soak_started_at + release.soak_period_hours.hours
    Time.current >= soak_end_time
  end
end
