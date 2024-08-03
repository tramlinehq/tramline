Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      exception: event.payload[:exception],
      exception_object: event.payload[:exception_object],
      params: event.payload[:params].except(*exceptions),
      remote_ip: event.payload[:remote_ip],
      ip: event.payload[:ip],
      request_id: event.payload[:headers]["action_dispatch.request_id"]
    }
  end
  config.lograge.formatter = Class.new do |fmt|
    def fmt.call(data)
      message =
        if data[:controller].present? && data[:action].present?
          "#{data[:controller]}##{data[:action]}"
        else
          "Request"
        end

      {msg: message}.merge(data)
    end
  end
  config.lograge.custom_payload do |controller|
    {
      host: controller.request.host,
      user_id: controller.try(:current_user).try(:id)
    }
  end
  # config.lograge.ignore_actions = ["IntegrationListeners::GithubController#events"]
end
