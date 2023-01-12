# == Schema Information
#
# Table name: slack_integrations
#
#  id                          :uuid             not null, primary key
#  oauth_access_token          :string
#  original_oauth_access_token :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
class SlackIntegration < ApplicationRecord
  has_paper_trail
  encrypts :oauth_access_token, deterministic: true

  include Vaultable
  include Providable
  include Displayable
  include Rails.application.routes.url_helpers

  attr_accessor :code

  before_create :complete_access

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

  LIST_CHANNELS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    description: [:purpose, :value],
    is_private: :is_private,
    member_count: :num_members
  }

  def install_path
    unless integration.notification? || integration.build_channel?
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end

    BASE_INSTALLATION_URL
      .expand(params: {
        client_id: creds.integrations.slack.client_id,
        redirect_uri: redirect_uri,
        scope: creds.integrations.slack.scopes,
        state: integration.installation_state
      }).to_s
  end

  def complete_access
    self.oauth_access_token = Installations::Slack::Api.oauth_access_token(code)
  end

  def channels
    installation.list_channels(LIST_CHANNELS_TRANSFORMATIONS)
  end

  def installation
    Installations::Slack::Api.new(oauth_access_token)
  end

  def notify!(channel, message, type, params)
    installation.rich_message(channel, message, notifier(type, params))
  end

  alias_method :deploy!, :notify! # slack can currently also be used as a deployment channel

  def notifier(type, params)
    Notifiers::Slack::Builder.build(type, **params)
  end

  def to_s
    "slack"
  end

  def creatable?
    false
  end

  def connectable?
    true
  end

  def store?
    false
  end

  private

  def redirect_uri
    if Rails.env.development?
      slack_callback_url(host: ENV["HOST_NAME"], port: "3000", protocol: "https")
    else
      slack_callback_url(host: ENV["HOST_NAME"], protocol: "https")
    end
  end
end
