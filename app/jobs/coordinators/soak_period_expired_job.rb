class Coordinators::SoakPeriodExpiredJob < ApplicationJob
  sidekiq_options queue: :high

  def perform(beta_soak_id)
    beta_soak = BetaSoak.find_by(id: beta_soak_id)
    return unless beta_soak

    if beta_soak.expired?
      Coordinators::SoakPeriod::End.call(beta_soak, nil)
    else
      time_remaining = beta_soak.time_remaining
      self.class.perform_in(time_remaining.seconds.to_i, beta_soak.id)
    end
  end
end
