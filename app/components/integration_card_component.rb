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

  def initialize(app, integration, category)
    @app = app
    @integration = integration
    @category = category
  end

  attr_reader :integration
  delegate :connected?, :disconnected?, :providable, :connection_data, :providable_type, :ci_cd?, to: :integration, allow_nil: true
  alias_method :provider, :providable
  delegate :creatable?, :connectable?, to: :provider

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
    integration.disconnectable? && ci_cd?
  end
end
