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

    def notify_channel
      train
        .app
        .config
        .notification_channel
    end

    def oauth_access_token
      train
        .app
        .notification_provider
        .oauth_access_token
    end
  end
end
