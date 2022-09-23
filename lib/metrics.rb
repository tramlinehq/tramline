class Metrics
  def self.with_object(object)
    prefix = object.class.name.underscore.tr("/", ".")
    new(prefix)
  end

  def self.with_prefix(prefix)
    new(prefix)
  end

  def initialize(prefix)
    @prefix = prefix
  end

  def gauge(event, count)
    name = "#{@prefix}.#{event}"
    Statsd.instance.gauge(name, count)
  end

  def increment(event)
    name = "#{@prefix}.#{event}"
    Statsd.instance.increment(name)
  end

  def histogram(event, count)
    name = "#{@prefix}.#{event}"
    Statsd.instance.histogram(name, count)
  end
end
