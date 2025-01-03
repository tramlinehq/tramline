class StoreSubmissions::AppStore::FindBuildJob
  include Sidekiq::Job
  extend Loggable
  include Backoffable

  queue_as :high

  # Maximum number of retry attempts allowed for this job
  MAX_ATTEMPTS = 8

  attr_accessor :current_jid
  # When performing the job for the first time, job_id is nil.
  # When retrying, job_id is set to the original job ID to allow the retry mechanism to work properly.
  def perform(submission_id, job_id = nil)
    # Set the current job ID for tracking retries
    set_current_jid(job_id)

    begin
      submission = AppStoreSubmission.find(submission_id)
      return unless submission.actionable?

      submission.find_build.value!
      submission.prepare_for_release!
    rescue => ex
      increment_attempts

      if should_retry?(ex) && track_attempts <= MAX_ATTEMPTS
        backoff_value = backoff_in(attempt: track_attempts, period: :minutes, type: :static, factor: 1)
        # Pass the backoff value to perform this job with the specified time and the same submission_id and current_jid
        # Using the same job ID ensures proper tracking of retries in the retry mechanism
        self.class.perform_in(backoff_value, submission_id, current_jid)
      else
        handle_exhausted_retries(submission_id, ex)
      end
    ensure
      # Clear retry tracking if the maximum attempts have been exceeded.
      # Once the retry limit is reached, the cache key is removed from Redis.
      clear_attempts if track_attempts > MAX_ATTEMPTS
    end
  end

  private

  # Fetch the current retry attempt count for this job from the cache
  # Returns the current attempt using the cache key, or initializes it to 0 if the cache key does not exist
  def track_attempts
    Rails.cache.fetch(cache_key) { 0 }
  end

  # Increment the retry attempts by 1 and update the value in the cache
  def increment_attempts
    # Fetch the value from the Rails cache using the cache_key method, then incrementing this value and updating it on the same key
    attempts = track_attempts
    # Set an expiry time of 7 days to avoid unnecessary accumulation in Redis
    Rails.cache.write(cache_key, attempts + 1, expires_in: 7.days)
  end

  # Clear the retry attempts cache to prevent stale data
  # This method is called when the maximum retry attempts have been exceeded, so the key is no longer needed
  def clear_attempts
    Rails.cache.delete(cache_key)
  end

  # Generate a unique cache key for tracking this job's retry attempts
  # The cache key is based on the job ID to ensure isolation between jobs
  def cache_key
    "job_#{current_jid}_retry_attempts"
  end

  # Determine if the exception is eligible for a retry
  # Retry only for specific exceptions, such as "build not found" errors
  def should_retry?(exception)
    exception.is_a?(Installations::Error) && exception.reason == :build_not_found
  end

  # Handle cases where retry attempts have been exhausted
  # Logs the error or raises it further depending on the exception type
  def handle_exhausted_retries(submission_id, exception)
    if exception.is_a?(Installations::Error)
      raise exception
    else
      Rails.logger.error("Unexpected Error: #{exception.message}. Job failed.")
    end
  end

  # Set the job ID for tracking retries
  # Uses the provided job ID or defaults to the Sidekiq job ID (jid)
  # `jid` is a globally unique identifier provided by Sidekiq for each job
  def set_current_jid(job_id)
    self.current_jid = job_id || jid
  end
end
