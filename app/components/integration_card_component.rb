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
    :disconnectable_categories?,
    :further_setup?, to: :integration, allow_nil: true
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

  def edit_config_path
    case integration.category
    when "version_control" then edit_app_version_control_config_path
    when "ci_cd" then edit_app_ci_cd_config_path
    when "build_channel" then edit_app_build_channel_config_path
    when "monitoring" then edit_app_monitoring_config_path
    when "project_management" then edit_app_project_management_config_path
    else unsupported_integration_category
    end
  end

  private

  def edit_app_version_control_config_path
    case integration.providable_type
    when "GithubIntegration" then edit_app_version_control_github_config_path(@app)
    when "GitlabIntegration" then edit_app_version_control_gitlab_config_path(@app)
    when "BitbucketIntegration" then edit_app_version_control_bitbucket_config_path(@app)
    else unsupported_integration_type
    end
  end

  def edit_app_ci_cd_config_path
    case integration.providable_type
    when "BitriseIntegration" then edit_app_ci_cd_bitrise_config_path(@app)
    else unsupported_integration_type
    end
  end

  def edit_app_build_channel_config_path
    case integration.providable_type
    when "GoogleFirebaseIntegration" then edit_app_build_channel_google_firebase_config_path(@app)
    else unsupported_integration_type
    end
  end

  def edit_app_monitoring_config_path
    case integration.providable_type
    when "BugsnagIntegration" then edit_app_monitoring_bugsnag_config_path(@app)
    else unsupported_integration_type
    end
  end

  def edit_app_project_management_config_path
    case integration.providable_type
    when "JiraIntegration" then edit_app_project_management_jira_config_path(@app)
    when "LinearIntegration" then edit_app_project_management_linear_config_path(@app)
    else unsupported_integration_type
    end
  end

  def unsupported_integration_category
    raise TypeError, "Unsupported integration category: #{integration.category}"
  end

  def unsupported_integration_type
    raise TypeError, "Unsupported integration type: #{integration.providable_type}"
  end
end
