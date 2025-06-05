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

  using RefinedString
  include Vaultable
  include Providable
  include Displayable
  include Loggable
  include Rails.application.routes.url_helpers

  delegate :integrable, to: :integration
  delegate :cache, to: Rails

  attr_accessor :code

  before_create :complete_access
  after_create_commit :fetch_channels

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

  CREATE_CHANNEL_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    is_private: :is_private
  }

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
  CODE_SNIPPET_CHARACTER_LIMIT = 3500
  MAX_RETRY_ATTEMPTS = 3
  RETRYABLE_ERRORS = ["name_taken"]

  NOTIFICATION_KINDS_CONTAINING_CHANGELOG = [:rc_finished, :production_rollout_started]

  def needs_changelog_threading?(type)
    type.to_sym.in?(NOTIFICATION_KINDS_CONTAINING_CHANGELOG)
  end

  def controllable_rollout?
    false
  end

  def further_setup?
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
    return if oauth_access_token.present?
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
    RefreshSlackChannelsJob.perform_async(id)
  end

  def populate_channels!
    cache.write(channels_cache_key, get_all_channels, expires_in: CACHE_EXPIRY)
  end

  def channels
    cache
      .fetch(channels_cache_key, expires_in: CACHE_EXPIRY) { get_all_channels }
      .map { |c| c.slice(:id, :name, :is_private) }
  end

  def channels_cache_key
    "app/#{integrable.id}/slack_integration/#{id}/channels"
  end

  def notify!(channel, message, type, params, file_id = nil, file_title = nil)
    response = installation.rich_message(channel, message, notifier(type, params), file_id, file_title)
    return if response.blank?

    handle_changelog_thread(response, channel, params) if needs_changelog_threading?(type)
  rescue => e
    elog(e, level: :warn)
  end

  def notify_changelog_in_thread!(channel, thread_id, changelog, show_changelog_header:)
    # If we are showing the header, we must show the full changelog.
    # If not, we show only the spillover from the main message.

    notifiable_changes = show_changelog_header ? changelog : changelog&.[](Notifiers::Slack::Renderers::Changelog.changes_limit..)
    return if notifiable_changes.blank?

    notifiable_changes.in_groups_of(Notifiers::Slack::Renderers::Changelog.changes_limit, false).each_with_index do |notifiable_change_group, index|
      payload = notifier(:changelog, {
        changes: notifiable_change_group,

        # index.zero? is checked to show header only before first message in thread
        release_changelog_header: show_changelog_header && index.zero?
      })
      installation.message(channel, "Changelog", block: payload, thread_id:)
    end
  rescue => e
    elog(e, level: :warn)
  end

  def handle_changelog_thread(response, channel, params)
    thread_id = response.dig("message", "ts")
    changes_since_last_run = params[:changes_since_last_run]

    # No need to show the header here because we have already shown it in main message.
    # Just a spillover of changes from main message to thread.
    notify_changelog_in_thread!(channel, thread_id, changes_since_last_run, show_changelog_header: false)

    # Here we are showing changes since last release.
    # Header is to be shown if we previously have displayed changes_since_last_run.
    notify_changelog_in_thread!(channel, thread_id, params[:changes_since_last_release], show_changelog_header: changes_since_last_run.present?)
  end

  def notify_with_snippet!(channel, message, type, params, snippet_content, snippet_title)
    message_response = notify!(channel, message, type, params)
    return unless message_response

    thread_id = message_response.dig("message", "ts")
    messages = snippet_content.break_into_chunks(CODE_SNIPPET_CHARACTER_LIMIT)
    messages.each_with_index.map do |msg, idx|
      msg = "```#{msg}```"
      msg.prepend("*#{snippet_title}*\n\n") if idx == 0
      installation.message(channel, msg, thread_id:)
    end
  rescue => e
    elog(e, level: :warn)
  end

  def upload_file!(file, file_name)
    installation.upload_file(file, file_name)
  rescue => e
    elog(e, level: :warn)
  end

  def create_channel!(name)
    execute_with_retry do |attempt|
      channel_name = name
      channel_name = [name, attempt].join("_") if attempt > 0
      installation.create_channel(CREATE_CHANNEL_TRANSFORMATIONS, channel_name)
    end
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

  def channel_deep_link(channel_id)
    "slack://channel?team=#{integration.metadata["id"]}&id=#{channel_id}"
  end

  private

  def execute_with_retry(attempt: 0, &)
    yield(attempt)
  rescue Installations::Error => ex
    elog(ex, level: :warn)
    return if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if RETRYABLE_ERRORS.include?(ex.reason)
      execute_with_retry(attempt: next_attempt, &)
    end
  rescue => ex
    elog(ex, level: :warn)
  end

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
