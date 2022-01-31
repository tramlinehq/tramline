class Integration < ApplicationRecord
  using StringRefinement

  belongs_to :app

  class IntegrationNotImplemented < StandardError; end

  unless const_defined?(:LIST)
    LIST = {
      "version_control" => %w[github],
      "ci_cd" => %w[github_actions],
      "notification" => %w[slack],
      "build_artifact" => %w[google_play_store]
    }.freeze
  end

  enum category: LIST.keys.zip(LIST.keys).to_h
  enum provider: LIST.values.flatten.zip(LIST.values.flatten).to_h

  attr_reader :integration_type
  attr_accessor :current_user, :code
  encrypts :oauth_access_token, deterministic: true

  validate -> { provider.in?(LIST[category]) }

  def decide
    if github? || github_actions?
      @integration_type = Github.new(self, current_user)
    elsif slack?
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
        .expand(app_name: creds.integrations.github.app_name, params: { state: integration.installation_state }).to_s
    end

    def complete_access
      # do nothing
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

      @api = Integrations::Slack::Api.new
    end

    def install_path
      raise Integration::IntegrationNotImplemented, "We don't support that yet!" unless integration.notification?

      BASE_INSTALLATION_URL
        .expand(params: {
          client_id: creds.integrations.slack.client_id,
          redirect_uri: redirect_uri,
          scope: creds.integrations.slack.scopes,
          state: integration.installation_state
        }).to_s
    end

    def complete_access
      integration.oauth_access_token = @api.oauth_access_token(integration.code)
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
