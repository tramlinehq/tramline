class Coordinators::SoakPeriodCompletionJob < ApplicationJob
  sidekiq_options retry: 3, queue: :default

  def perform(beta_soak_id)
    beta_soak = BetaSoak.find_by(id: beta_soak_id)
    return unless beta_soak
    Coordinators::SoakPeriod::End.call(beta_soak, nil)
  end
end
