class Coordinators::FireLifecycleHooks
  def self.call(resource, event:)
    new(resource, event).call
  end

  def initialize(resource, event)
    @resource = resource
    @event = event.to_s
  end

  def call
    return if hooks.empty?

    hooks.each do |hook|
      LifecycleHooks::FireJob.perform_async(hook.id, @resource.class.name, @resource.id)
    end
  end

  private

  def hooks
    @hooks ||= train.lifecycle_hooks.active.for_event(@event).to_a
  end

  def train
    @train ||= @resource.respond_to?(:train) ? @resource.train : @resource.release_platform_run.train
  end
end
