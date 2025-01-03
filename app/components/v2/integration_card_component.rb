class V2::IntegrationCardComponent < V2::BaseComponent
  CONNECTABLE_PROVIDER_TO_TITLE = {
    app_store: "API details",
    bugsnag: "Auth Token",
    firebase: "Firebase Service Account JSON Key",
    google_play_store: "Service Account JSON Key",
    crashlytics: "Service Account JSON Key",
    bitrise: "Access Token"
  }

  def initialize(app, integration, category)
    @app = app
    @integration = integration
    @category = category
  end

  attr_reader :integration
  delegate :connected?, :disconnected?, :providable, :connection_data, :providable_type, :ci_cd?, to: :integration, allow_nil: true
  alias_method :provider, :providable
  delegate :creatable?, :connectable?, to: :provider

  def repeated_integration
    Integration.existing_integration(@app, providable_type)
  end

  # Retrieves repeated integrations across apps for the given app and providable type
  def repeated_integrations_across_app
    Integration.existing_integrations_across_app(@app, providable_type)
  end

  def connect_path
    connect_app_integrations_path(@app, integration)
  end

  def reuse_existing_integration_path(existing_integration)
    reuse_app_integration_path(@app, existing_integration)
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
      locals: {app: @app, integration: @integration, category: @category, url: reuse_existing_integration_path(existing_integration), type: providable_type, provider: provider})
  end

  def reusable_integrations_across_app_form_partial(existing_integration)
    render(partial: "integrations/app_reuseable",
      locals: {app: @app, existing_integration: existing_integration, category: @category, url: reuse_integration_across_app_app_integrations_path, type: providable_type, provider: provider})
  end

  def disconnectable?
    integration.disconnectable? && ci_cd?
  end
end
