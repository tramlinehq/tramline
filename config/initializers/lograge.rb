Rails.application.configure do
  config.lograge.custom_options = lambda do |event|
    payload = event.payload
    param_exceptions = %w[controller action format id]

    {
      exception: payload[:exception],
      exception_object: payload[:exception_object],
      params: payload[:params]&.except(*param_exceptions),
      remote_ip: payload[:remote_ip],
      ip: payload[:ip],
      request_id: payload[:headers] && payload[:headers]["action_dispatch.request_id"]
    }
  end

  config.lograge.custom_payload do |controller|
    {
      host: controller.request.host,
      user_id: controller.try(:current_user).try(:id)
    }
  end

  config.lograge.before_format = ->(data, payload) do
    data.delete(:error)
    # Remove empty hashes to prevent type mismatches
    # These are set to empty hashes in Lograge's ActionCable subscriber
    # https://github.com/roidrage/lograge/blob/v0.12.0/lib/lograge/log_subscribers/action_cable.rb#L14-L16
    %i[method path format].each do |key|
      data[key] = nil if data[key] == {}
    end

    data
  end

  config.lograge.formatter = ->(data) do
    message =
      if data[:controller].present? && data[:action].present?
        "#{data[:controller]}##{data[:action]}"
      else
        "Request"
      end

    {msg: message}.merge(data)
  end
end
