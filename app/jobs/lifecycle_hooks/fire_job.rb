class LifecycleHooks::FireJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(hook_id, resource_class_name, resource_id)
    hook = LifecycleHook.find_by(id: hook_id)
    return unless hook
    return unless hook.active?

    resource_class = safe_resource_class(resource_class_name)
    resource = resource_class&.find_by(id: resource_id)
    return unless resource

    context = build_context(resource)
    result = LifecycleHooks::Runner.call(hook, context)

    if result.ok? && result.value![:success]
      resource.event_stamp!(
        reason: :lifecycle_hook_fired,
        kind: :notice,
        data: stamp_data(hook, result.value!)
      )
    elsif result.ok?
      response = result.value!
      failure_summary = "HTTP #{response[:status]}"
      resource.event_stamp!(
        reason: :lifecycle_hook_failed,
        kind: :error,
        data: stamp_data(hook, {error: failure_summary, status: response[:status]})
      )
      notify_failure(hook, resource, context, StandardError.new("#{failure_summary}: #{response[:body_preview]}"))
    else
      error = result.error
      resource.event_stamp!(
        reason: :lifecycle_hook_failed,
        kind: :error,
        data: stamp_data(hook, {error: error.message})
      )
      elog(error, level: :warn)
      notify_failure(hook, resource, context, error)
    end
  end

  private

  ALLOWED_RESOURCE_CLASSES = %w[AppStoreSubmission PlayStoreSubmission AppStoreRollout PlayStoreRollout].freeze

  def safe_resource_class(name)
    ALLOWED_RESOURCE_CLASSES.include?(name) ? name.constantize : nil
  end

  def build_context(resource)
    rpr = resource.release_platform_run
    release = rpr&.release
    platform = rpr&.platform
    {
      "build_number" => resource.build_number.to_s,
      "version" => resource.release_version.to_s,
      "platform" => platform.to_s,
      "release_id" => release&.id.to_s,
      "release_branch" => release&.release_branch.to_s,
      "release_url" => release&.live_release_link.to_s
    }
  end

  def stamp_data(hook, extra)
    {
      hook_id: hook.id,
      hook_name: hook.name,
      hook_event: hook.event
    }.merge(extra.is_a?(Hash) ? extra : {})
  end

  def notify_failure(hook, resource, context, error)
    return unless hook.notify_on_failure?
    channel = hook.failure_notification_channel
    return if channel.blank?

    app = resource.release_platform_run&.release&.train&.app
    return unless app&.notifications_set_up?

    rendered_message = render_failure_message(hook, context, error)
    channel_id = channel["id"] || channel[:id]
    return if channel_id.blank?

    app.notification_provider.notify!(
      channel_id,
      "Lifecycle hook failed",
      :lifecycle_hook_failed,
      {
        hook_name: hook.name,
        hook_event: hook.event,
        failure_message: rendered_message,
        error_summary: error.message.to_s.byteslice(0, 200)
      }
    )
  rescue => e
    elog(e, level: :warn)
  end

  def render_failure_message(hook, context, error)
    template = hook.failure_message_template.to_s
    return "Lifecycle hook #{hook.name} failed: #{error.message}" if template.blank?

    merged = context
      .merge(hook.static_variables.to_h.transform_keys(&:to_s))
      .merge(
        "hook_name" => hook.name,
        "hook_event" => hook.event,
        "error_message" => error.message.to_s
      )
    template.gsub(/%\{(\w+)\}/) { merged.fetch(Regexp.last_match(1), "") }
  rescue
    "Lifecycle hook #{hook.name} failed"
  end
end
