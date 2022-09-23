class Statsd
  include Singleton

  def reset!
    @statsd = nil
  end

  def statsd
    @statsd ||= create_connection
  end

  def close
    @statsd&.flush
    @statsd&.close
    @statsd = nil
  end

  DELEGATED_METHODS = %i[
    close
    count
    flush
    gauge
    histogram
    increment
    time
    timing
  ]
  delegate(*DELEGATED_METHODS, to: :statsd)

  private

  def create_connection
    Datadog::Statsd.new("localhost", 8125)
  end
end
