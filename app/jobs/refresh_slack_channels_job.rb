class RefreshSlackChannelsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(slack_integration_id)
    slack_integration = SlackIntegration.find(slack_integration_id)
    return unless slack_integration

    slack_integration.populate_channels!
  end
end
