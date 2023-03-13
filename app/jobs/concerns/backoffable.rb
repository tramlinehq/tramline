module Backoffable
  AttemptMustBeGreaterThanZero = Class.new(StandardError)
  InvalidPeriod = Class.new(ArgumentError)
  InvalidType = Class.new(ArgumentError)
  ALLOWED_PERIODS = [:minutes, :seconds]
  ALLOWED_TYPES = [:exponential, :linear]
  LINEAR_BACKOFF_FACTOR = 5

  protected

  # goes roughly like: 10, 20, 40, 80, 160, 320, 640, 1280, 2560... for exponential
  # goes roughly like: 10, 15, 20, 25, 30, 35, 40, 45, 50, 55... for linear
  def backoff_in(attempt: 1, period: :minutes, type: :exponential)
    raise InvalidPeriod unless period.in?(ALLOWED_PERIODS)
    raise InvalidType unless type.in?(ALLOWED_TYPES)
    raise AttemptMustBeGreaterThanZero if attempt.zero?

    base_delay = 5 # set the initial delay

    delay = case type
    when :exponential
      base_delay * 2**attempt
    when :linear
      base_delay + (LINEAR_BACKOFF_FACTOR * attempt)
    end

    delay += rand(0..1000) / 1000.0 # add some jitter
    delay.to_i.public_send(period)
  end
end
