module Backoffable
  AttemptMustBeGreaterThanZero = Class.new(StandardError)
  InvalidPeriod = Class.new(ArgumentError)
  ALLOWED_PERIODS = [:minutes, :seconds]

  protected

  # goes roughly like: 10, 20, 40, 80, 160, 320, 640, 1280, 2560...
  def backoff_in(attempt = 1, period = :minutes)
    raise InvalidPeriod unless period.in?(ALLOWED_PERIODS)
    raise AttemptMustBeGreaterThanZero if attempt.zero?

    delay = 5 # set the initial delay
    delay *= 2**attempt # exp the delay for each retry attempt
    delay += rand(0..1000) / 1000.0 # add some jitter
    delay.to_i.public_send(period)
  end
end
