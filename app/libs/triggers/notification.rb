class Triggers::Notification
  def self.dispatch!(**args)
    new(**args).dispatch!
  end

  def initialize(train:, message:, text_block: {}, channel: nil, provider: nil)
    @train = train
    @message = message
    @text_block = text_block
    @channel = channel || train.app.config.notification_channel_name
    @provider = provider || train.app.notification_provider
  end

  def dispatch!
    slack_api.rich_message(channel, message, text_block)
  end

  private

  attr_reader :train, :message, :text_block, :channel, :provider

  def slack_api
    Installations::Slack::Api.new(provider&.oauth_access_token)
  end
end
