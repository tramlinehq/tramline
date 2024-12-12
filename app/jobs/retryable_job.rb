module RetryableJob
  extend ActiveSupport::Concern

  included do
    class_attribute :backoff_multiplier, default: 2
    class_attribute :max_backoff_time, default: 30.minutes
    class_attribute :MAX_RETRIES, default: 8
  end

  def retry_with_backoff(exception, retry_context = {})
    retry_context = normalize_retry_context(retry_context)

    Rails.logger.info(
      "Retry attempt for job: #{self.class.name}, " \
      "retry_count: #{retry_context[:retry_count]}, " \
      "exception: #{exception.class.name}, " \
      "exception_message: #{exception.message}, " \
      "backtrace: #{exception.backtrace&.first}"
    )

    if retry_context[:retry_count] <= self.class.MAX_RETRIES
      backoff_value = compute_backoff(retry_context[:retry_count])
      enqueue_args = []
      context_hash = {
        "retry_count" => retry_context[:retry_count],
        "original_exception" => {
          "class" => exception.class.name,
          "message" => exception.message
        }
      }

      # Add step_run_id if present, otherwise use a UUID
      if retry_context[:step_run_id]
        enqueue_args << retry_context[:step_run_id]
        context_hash["step_run_id"] = retry_context[:step_run_id]
      else
        enqueue_args << SecureRandom.uuid
      end

      # Add optional arguments if they exist
      if retry_context[:op_name]
        enqueue_args << retry_context[:op_name]
      end

      # Add context hash as the last argument
      enqueue_args << context_hash

      self.class.perform_in(backoff_value, *enqueue_args)
    else
      handle_retries_exhausted(retry_context.merge(last_exception: exception))
    end
  end

  private

  def normalize_retry_context(context)
    # Ensure context is a hash
    context = context.is_a?(Hash) ? context.dup : {}

    # Increment retry count, defaulting to 0
    context[:retry_count] = (context[:retry_count].to_i || 0) + 1

    context
  end

  # Compute the backoff value based on the retry count
  def compute_backoff(retry_count)
    # Use floating point exponentiation and convert to integer
    [backoff_multiplier**retry_count, max_backoff_time.to_i].min
  end

  # Default implementation of handling exhausted retries
  def handle_retries_exhausted(context)
    Rails.logger.error(
      "Retries exhausted for job: #{self.class.name}, " \
      "context: #{context.inspect}"
    )

    # Default implementation can be overridden
    raise "Retries exhausted for #{self.class.name}"
  end
end
