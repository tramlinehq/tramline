class StoreRollouts::AppStore::FindLiveReleaseJob
  include Sidekiq::Job
  include RetryableJob

  self.MAX_RETRIES = 6000
  queue_as :high

  def compute_backoff(retry_count)
    ex = @last_exception
    if ex.is_a?(AppStoreRollout::ReleaseNotFullyLive)
      5.minutes.to_i
    else
      :kill
    end
  end

  def perform(rollout_id, force = false, retry_args = {})
    @last_exception = retry_args.is_a?(Hash) ? retry_args[:last_exception] : nil

    retry_args = {} if retry_args.is_a?(Integer)
    retry_count = retry_args[:retry_count] || 0

    rollout = AppStoreRollout.find(rollout_id)

    begin
      rollout.track_live_release_status
    rescue AppStoreRollout::ReleaseNotFullyLive => e
      retry_with_backoff(e, {rollout_id: rollout_id, retry_count: retry_count})
      raise e
    end
  end
end
