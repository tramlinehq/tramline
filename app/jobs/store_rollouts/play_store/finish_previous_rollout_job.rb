class StoreRollouts::PlayStore::FinishPreviousRolloutJob
  include Sidekiq::Job
  extend Loggable

  def perform(rollout_id)
    nil
  end
end
