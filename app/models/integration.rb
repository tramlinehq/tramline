class Integration < ApplicationRecord
  using RefinedString

  belongs_to :app

  class IntegrationNotImplemented < StandardError; end

  unless const_defined?(:LIST)
    LIST = {
      "version_control" => %w[github],
      "ci_cd" => %w[github_actions],
      "notification" => %w[slack],
      "build_channel" => %w[slack]
    }.freeze
  end

  LIST_DESCRIPTIONS = {
    "version_control": "Automatically create release branches, tags, and more.",
    "ci_cd": "Keep up to date with the status of the latest release builds as they're made available.",
    "notification": "Send release activity notifications at the right time, to the right people.",
    "build_channel": "Quickly see where your release stands in the app store."
  }

  enum category: LIST.keys.zip(LIST.keys).to_h
  enum provider: LIST.values.flatten.zip(LIST.values.flatten).to_h
  enum status: {
    partially_connected: "partially_connected",
    fully_connected: "fully_connected",
    disconnected: "disconnected"
  }

  attr_reader :integration_type
  attr_accessor :current_user, :code
  encrypts :oauth_access_token, deterministic: true

  validate -> { provider.in?(LIST[category]) }

  DEFAULT_CONNECT_STATUS = {
    Integration.categories[:version_control] => Integration.statuses[:partially_connected],
    Integration.categories[:ci_cd] => Integration.statuses[:partially_connected],
    Integration.categories[:notification] => Integration.statuses[:partially_connected],
    Integration.categories[:build_channel] => Integration.statuses[:fully_connected]
  }

  MINIMAL_REQUIRED_SET = [:version_control, :ci_cd, :notification]

  def self.ready?
    where(category: MINIMAL_REQUIRED_SET, status: :fully_connected).size == MINIMAL_REQUIRED_SET.size
  end

  def self.completable?
    where(category: MINIMAL_REQUIRED_SET, status: :partially_connected).size == MINIMAL_REQUIRED_SET.size
  end

  def connect?
    !partially_connected? && !fully_connected?
  end

  def workflows
    [] unless github_actions? && ci_cd?
    Installations::Github::Api.new(installation_id).list_workflows(active_code_repo.values.first)
  end

  def channels
    if github? && version_control?
      Installations::Github::Api.new(installation_id).list_repos
    elsif github_actions? && ci_cd?
      Installations::Github::Api.new(installation_id).list_repos
    elsif slack? && notification?
      Installations::Slack::Api.new(oauth_access_token).list_channels
    elsif slack? && build_channel?
      Installations::Slack::Api.new(oauth_access_token).list_channels
    else
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end
  end

  def decide
    if (version_control? && github?) || (ci_cd? && github_actions?)
      @integration_type = Github.new(self, current_user)
    elsif (notification? && slack?) || (build_channel? && slack?)
      @integration_type = Slack.new(self, current_user)
    else
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end
  end

  def install_path
    @integration_type.install_path
  end

  def installation_state
    {
      organization_id: app.organization.id,
      app_id: app.id,
      integration_category: category,
      integration_provider: provider,
      user_id: current_user.id
    }.to_json.encode
  end

  class Github
    include Rails.application.routes.url_helpers

    attr_reader :integration, :current_user

    BASE_INSTALLATION_URL =
      Addressable::Template.new("https://github.com/apps/{app_name}/installations/new{?params*}")

    def initialize(integration, current_user)
      @integration = integration
      @current_user = current_user
    end

    def install_path
      unless integration.version_control? || integration.ci_cd?
        raise Integration::IntegrationNotImplemented, "We don't support that yet!"
      end

      BASE_INSTALLATION_URL
        .expand(app_name: creds.integrations.github.app_name, params: {
          state: integration.installation_state
        }).to_s
    end

    def complete_access
      # do nothing
    end

    def register_webhook
      Installations::Github::Api
        .new(integration.installation_id)
        .create_repo_webhook!(
          integration.active_code_repo,
          github_events_url(integration.app.id, integration.installation_id),
          ["workflow_run"]
        )
    end

    private

    def creds
      Rails.application.credentials
    end
  end

  class Slack
    include Rails.application.routes.url_helpers

    attr_reader :integration, :current_user

    BASE_INSTALLATION_URL =
      Addressable::Template.new("https://slack.com/oauth/v2/authorize{?params*}")

    def initialize(integration, current_user)
      @integration = integration
      @current_user = current_user
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
      integration.oauth_access_token = Installations::Slack::Api.oauth_access_token(integration.code)
    end

    private

    def redirect_uri
      if Rails.env.development?
        slack_callback_url(host: ENV["HOST_NAME"], port: "3000", protocol: "https")
      else
        slack_callback_url(host: ENV["HOST_NAME"], protocol: "https")
      end
    end

    def creds
      Rails.application.credentials
    end
  end
end
