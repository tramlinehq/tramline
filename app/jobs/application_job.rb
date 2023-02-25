class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError
  sidekiq_options retry: 0

  AttemptMustBeGreaterThanZero = Class.new(StandardError)

  protected

  def backoff_in_minutes(attempt = 1)
    raise AttemptMustBeGreaterThanZero if attempt.zero?
    delay = 5 # set the initial delay
    delay *= 2**attempt # exp the delay for each retry attempt
    delay += rand(0..1000) / 1000.0 # add some jitter
    delay.to_i.minutes
  end

  def logger
    @logger ||= Sidekiq.logger
  end
end
