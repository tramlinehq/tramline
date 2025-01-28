# The purpose of this concern is to retry jobs which require a large max number of retries.
# The existing retry mechanism in Sidekiq adds a [jitter](https://github.com/sidekiq/sidekiq/issues/5324)
# to the retry interval, which can cause the job to not meet the required wait time SLO.
# This is a workaround to retry jobs with a large max number of retries
# by re-enqueueing them with correct wait time SLO using custom retry metadata.
# This still relies on default sidekiq retry exhausted flow to handle retry exhaustion.

module RetryableJob
  extend ActiveSupport::Concern
  include Backoffable

  included do
    sidekiq_options retry: 0
  end

  class_methods do
    def enduring_retry_on(error_class,
      reason: nil,
      max_attempts: 2000,
      backoff: {
        period: :minutes,
        type: :linear,
        factor: Backoffable::LINEAR_BACKOFF_FACTOR
      })
      @retry_configs ||= []
      @retry_configs << {
        error_class: error_class,
        reason:,
        max_attempts: max_attempts,
        backoff: backoff
      }
    end

    def retry_configs
      @retry_configs || []
    end
  end

  def perform(*args)
    # Extract retry attempt and remaining attempts from args
    retry_meta = (args.last.is_a?(Hash) && args.last["_retry_meta"]) ? args.pop : nil
    current_attempt = retry_meta&.dig("_retry_meta", "attempt") || 1

    begin
      perform_work(*args)
    rescue => error
      handle_error(error, args, current_attempt)
    end
  end

  private

  def perform_work(*args)
    raise NotImplementedError, "#{self.class} must implement #perform_work"
  end

  def handle_error(error, args, current_attempt)
    matching_config = find_matching_retry_config(error)
    raise error unless matching_config

    if current_attempt < matching_config[:max_attempts]
      schedule_retry(error, args, current_attempt, matching_config)
    else
      handle_max_retries_exceeded(error, args)
    end

    # Log the error but don't raise it since we're handling the retry
    elog(error)
  end

  def find_matching_retry_config(error)
    self.class.retry_configs.find do |config|
      if config.fetch(:reason, nil).present?
        error.is_a?(config[:error_class]) && error.reason == config[:reason]
      else
        error.is_a?(config[:error_class])
      end
    end
  end

  def calculate_wait_time(current_attempt, config)
    backoff = config[:backoff]
    backoff_in(
      attempt: current_attempt,
      period: backoff[:period],
      type: backoff[:type],
      factor: backoff[:factor]
    )
  end

  def schedule_retry(error, args, current_attempt, config)
    retry_meta = {
      _retry_meta: {
        attempt: current_attempt + 1,
        original_error: error.class.name
      }
    }.deep_stringify_keys

    wait_time = calculate_wait_time(current_attempt, config)
    options = {wait: wait_time}

    self.class.set(options).perform_async(*args, retry_meta)
  end

  def handle_max_retries_exceeded(error, args)
    if respond_to?(:retries_exhausted)
      retries_exhausted(error, args)
    else
      raise error
    end
  end
end
