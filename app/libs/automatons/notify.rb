module Automatons
  class Notify
    attr_reader :train, :message, :text_block, :slack_api

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(train:, message:, text_block: {})
      @train = train
      @message = message
      @text_block = text_block
      @slack_api = Installations::Slack::Api.new(oauth_access_token)
    end

    def dispatch!
      slack_api.rich_message(notify_channel, message, text_block)
    end

    private

    delegate :oauth_access_token, to: :integration
    delegate :notification_channel, to: :integration

    def notify_channel
      notification_channel.values.first
    end

    def integration
      train
        .integrations
        .notification
        .first
    end
  end
end
