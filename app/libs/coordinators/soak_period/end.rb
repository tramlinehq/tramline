class Coordinators::SoakPeriod::End
  def self.call(beta_soak, who)
    new(beta_soak, who).call
  end

  def initialize(beta_soak, who)
    @beta_soak = beta_soak
    @release = beta_soak.release
    @who = who&.display_name || "Tramline"
  end

  def call
    return unless release.active?
    return unless beta_soak

    # Either ends:
    # 1. Automatically by Tramline
    # 2. By user action
    beta_soak.with_lock do
      return if beta_soak.ended_at.present?
      beta_soak.update!(ended_at: Time.current)
    end

    beta_soak.event_stamp!(reason: :beta_soak_ended, kind: :notice, data: {who: who})
    Coordinators::Signals.continue_after_soak_period!(release)
  end

  private

  attr_reader :release, :beta_soak, :who
end
