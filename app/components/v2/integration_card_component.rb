class V2::IntegrationCardComponent < V2::BaseComponent
  CONNECTABLE_PROVIDER_TO_TITLE = {
    app_store: "API details",
    bugsnag: "Auth Token",
    firebase: "Firebase Service Account JSON Key",
    google_play_store: "Service Account JSON Key",
    bitrise: "Access Token"
  }

  def initialize(app, integration, category)
    @app = app
    @integration = integration
    @category = category
  end

  attr_reader :integration
  delegate :connected?, :disconnected?, :providable, :connection_data, :providable_type, to: :integration, allow_nil: true
  alias_method :provider, :providable
  delegate :creatable?, :connectable?, to: :provider

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
end
