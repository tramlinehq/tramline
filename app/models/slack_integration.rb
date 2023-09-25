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
  include Loggable
  include Rails.application.routes.url_helpers

  delegate :app, to: :integration
  delegate :cache, to: Rails

  attr_accessor :code

  before_create :complete_access
  after_create_commit :fetch_channels

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

  CHANNELS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    description: [:purpose, :value],
    is_private: :is_private,
    member_count: :num_members
  }

  TEAM_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    domain: :domain,
    email_domain: :email_domain,
    icon: [:icon, :image_34],
    enterprise_id: :enterprise_id,
    enterprise_name: :enterprise_name
  }

  DEPLOY_MESSAGE = "A wild new release has appeared!"
  CACHE_EXPIRY = 1.month

  def controllable_rollout?
    false
  end

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

  def installation
    Installations::Slack::Api.new(oauth_access_token)
  end

  def metadata
    installation.team_info(TEAM_TRANSFORMATIONS)
  end

  def connection_data
    return unless integration.metadata
    "Workspace: #{integration.metadata["name"]} (#{integration.metadata["domain"]})"
  end

  def fetch_channels
    RefreshSlackChannelsJob.perform_later(id)
  end

  def populate_channels!
    cache.write(channels_cache_key, get_all_channels, expires_in: CACHE_EXPIRY)
  end

  def channels
    cache
      .fetch(channels_cache_key, expires_in: CACHE_EXPIRY) { get_all_channels }
      .map { |c| c.slice(:id, :name, :is_private) }
  end

  def build_channels(with_production:)
    cache
      .fetch(channels_cache_key, expires_in: CACHE_EXPIRY) { get_all_channels }
      .map { |c| c.slice(:id, :name) }
  end

  def channels_cache_key
    "app/#{app.id}/slack_integration/#{id}/channels"
  end

  def notify!(channel, message, type, params)
    installation.rich_message(channel, message, notifier(type, params))
  rescue => e
    elog(e)
  end

  def notify_with_snippet!(channel, message, type, params, snippet_content, snippet_title, snippet_filename)
    message_response = installation.rich_message(channel, message, notifier(type, params))
    thread_id = message_response.dig("message", "ts")
    installation.upload_snippet(channel, snippet_content, snippet_title, snippet_filename, thread_id:)
  rescue => e
    elog(e)
  end

  def deploy!(channel, params)
    notify!(channel, DEPLOY_MESSAGE, :deployment_finished, params)
  end

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

  def further_build_channel_setup?
    false
  end

  def public_icon_img
    nil
  end

  def project_link
    nil
  end

  def deep_link(_, _)
    nil
  end

  private

  def get_all_channels(cursor = nil, channels = [])
    resp = installation.list_channels(CHANNELS_TRANSFORMATIONS, cursor)
    channels.concat(resp[:channels])

    if resp[:next_cursor].present?
      get_all_channels(resp[:next_cursor], channels)
    else
      channels
    end
  end

  def redirect_uri
    if Rails.env.development?
      slack_callback_url(host: ENV["HOST_NAME"], port: "3000", protocol: "https")
    else
      slack_callback_url(host: ENV["HOST_NAME"], protocol: "https")
    end
  end
end
