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
  include Rails.application.routes.url_helpers

  attr_accessor :code

  before_create :complete_access

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

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
    Installations::Slack::Api.new(oauth_access_token).list_channels.map do |chan|
      ["#" + chan["name"], {chan["id"] => chan["name"]}.to_json]
    end
  end

  def to_s
    "slack"
  end

  def display
    "Slack"
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
