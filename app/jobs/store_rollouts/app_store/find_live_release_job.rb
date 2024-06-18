class StoreRollouts::AppStore::FindLiveReleaseJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 6000

  sidekiq_retry_in do |_count, ex|
    if ex.is_a?(AppStoreRollout::ReleaseNotFullyLive)
      5.minutes.to_i
    else
      elog(ex)
      :kill
    end
  end

  def perform(rollout_id)
    rollout = AppStoreRollout.find(rollout_id)
    return if rollout.terminal?
    rollout.track_live_release_status
  end
end
