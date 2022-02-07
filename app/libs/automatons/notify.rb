module Automatons
  class Notify
    attr_reader :message, :integration, :slack_api

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(message:, integration:)
      @message = message
      @integration = integration
      @slack_api = Installations::Slack::Api.new(oauth_access_token)
    end

    def dispatch!
      slack_api.message(notify_channel, message)
    end

    private

    delegate :oauth_access_token, to: :integration
    delegate :notification_channel, to: :integration

    def notify_channel
      notification_channel.values.first
    end
  end
end
