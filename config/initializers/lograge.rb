Rails.application.configure do
  config.lograge.enabled = true
  # config.lograge.ignore_actions = ["IntegrationListeners::GithubController#events"]
  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      params: event.payload[:params].except(*exceptions)
    }
  end

  config.lograge.formatter = Class.new do |fmt|
    def fmt.call(data)
      {msg: "request"}.merge(data)
    end
  end
end
