class IntegrationCardComponent < BaseComponent
  include Memery

  CONNECTABLE_PROVIDER_TO_TITLE = {
    app_store: "API details",
    bugsnag: "Auth Token",
    firebase: "Firebase Service Account JSON Key",
    google_play_store: "Service Account JSON Key",
    crashlytics: "Service Account JSON Key",
    bitrise: "Access Token"
  }

  def initialize(app, integration, category, pre_open_category = nil)
    @app = app
    @integration = integration
    @category = category
    @pre_open_category = pre_open_category
  end

  attr_reader :integration
  delegate :connected?,
    :disconnected?,
    :providable,
    :connection_data,
    :providable_type,
    :disconnectable_categories?, to: :integration, allow_nil: true
  delegate :creatable?, :connectable?, to: :provider
  alias_method :provider, :providable

  memoize def repeated_integrations_across_apps
    Integration.existing_integrations_across_apps(@app, providable_type)
  end

  def connect_path
    connect_app_integrations_path(@app, integration)
  end

  def logo
    image_tag("integrations/logo_#{provider}.png", width: 24, height: 24)
  end

  def creatable_modal_title
    CONNECTABLE_PROVIDER_TO_TITLE[provider.to_s.to_sym]
  end

  def creatable_form_partial
    render(partial: "integrations/providers/#{provider}",
      locals: {app: @app, integration: @integration, category: @category})
  end

  def connectable_form_partial
    render(partial: "integrations/connectable",
      locals: {app: @app, integration: @integration, category: @category, url: connect_path, type: providable_type})
  end

  def reusable_integration_form_partial(existing_integration)
    render(partial: "integrations/reusable",
      locals: {app: @app,
               integration: @integration,
               existing_integration: existing_integration,
               category: @category,
               url: reuse_app_integrations_path(@app),
               type: providable_type,
               provider: provider})
  end

  def reusable_integrations_form_partial(existing_integrations)
    render(partial: "integrations/app_reuseable",
      locals: {app: @app,
               integration: @integration,
               existing_integrations: existing_integrations,
               category: @category,
               url: reuse_app_integrations_path(@app),
               type: providable_type,
               provider: provider})
  end

  def disconnectable?
    integration.disconnectable? && disconnectable_categories?
  end

  def category_title
    "Configure #{Integration.human_enum_name(:category, @category)}"
  end

  def pre_open_category?
    @pre_open_category == @category
  end

  def category_config_turbo_frame_id
    "#{@category}_config"
  end

  def further_setup?
    # TODO: delegate to Integration properly
    integration.version_control? || integration.ci_cd? || integration.build_channel? || integration.monitoring?
  end

  def edit_config_path
    # TODO: find a potentially better way to route this
    if integration.version_control?
      case integration.providable_type
      when "GithubIntegration"
        edit_app_version_control_github_config_path(@app)
      when "GitlabIntegration"
        edit_app_version_control_gitlab_config_path(@app)
      when "BitbucketIntegration"
        edit_app_version_control_bitbucket_config_path(@app)
      else
        raise TypeError, "Unknown providable_type: #{integration.providable_type}"
      end
    elsif integration.ci_cd?
      case integration.providable_type
      when "BitriseIntegration"
        edit_app_ci_cd_bitrise_config_path(@app)
      else
        raise TypeError, "Unknown providable_type: #{integration.providable_type}"
      end
    elsif integration.build_channel?
      case integration.providable_type
      when "GoogleFirebaseIntegration"
        edit_app_build_channel_google_firebase_config_path(@app)
      else
        raise TypeError, "Unknown providable_type: #{integration.providable_type}"
      end
    elsif integration.monitoring?
      case integration.providable_type
      when "BugsnagIntegration"
        edit_app_monitoring_bugsnag_config_path(@app)
      else
        raise TypeError, "Unknown providable_type: #{integration.providable_type}"
      end
    else
      raise TypeError, "further_setup? should be true only for version_control, ci_cd, build_channel, or monitoring integrations"
    end
  end
end
