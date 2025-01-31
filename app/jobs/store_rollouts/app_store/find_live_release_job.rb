class StoreRollouts::AppStore::FindLiveReleaseJob < ApplicationJob
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
    rollout.track_live_release_status
  end
end
