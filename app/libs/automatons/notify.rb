module Automatons
  class Notify
    attr_reader :integration, :slack_api, :message

    delegate :oauth_access_token, to: :integration
    delegate :notification_channel, to: :integration

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(message:, integration:)
      @message = message
      @integration = integration
      @slack_api = Installations::Slack::Api.new(oauth_access_token)
    end

    def dispatch!
      slack_api.message(notification_channel.values.first, message)
    end
  end
end
