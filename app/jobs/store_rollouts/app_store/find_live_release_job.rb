class StoreRollouts::AppStore::FindLiveReleaseJob < ApplicationJob
  prepend Reenqueuer
  queue_as :high

  enduring_retry_on AppStoreRollout::ReleaseNotFullyLive,
    max_attempts: 6000,
    backoff: {period: :minutes, type: :static, factor: 5}

  def perform(rollout_id)
    rollout = AppStoreRollout.find(rollout_id)
    rollout.track_live_release_status
  end
end
