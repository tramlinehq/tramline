class SlackIntegration < ApplicationRecord
  include Vaultable
  include Rails.application.routes.url_helpers

  has_paper_trail

  has_one :integration, as: :providable

  encrypts :oauth_access_token, deterministic: true

  attr_accessor :code

  before_save :complete_access

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

  def install_path
    raise Integration::IntegrationNotImplemented, "We don't support that yet!" unless integration.notification? || integration.build_channel?

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
    Installations::Slack::Api.new(oauth_access_token).list_channels
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

  private

  def redirect_uri
    if Rails.env.development?
      slack_callback_url(host: ENV.fetch("HOST_NAME", nil), port: "3000", protocol: "https")
    else
      slack_callback_url(host: ENV.fetch("HOST_NAME", nil), protocol: "https")
    end
  end
end
