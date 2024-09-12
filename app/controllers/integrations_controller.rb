class IntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[connect create index build_artifact_channels destroy]
  before_action :set_integration, only: %i[connect create]
  before_action :set_providable, only: %i[connect create]

  def connect
    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def index
    @pre_open_category = Integration.categories[params[:integration_category]]
    set_integrations_by_categories
    set_tab_configuration
  end

  def create
    if @integration.save
      redirect_to app_path(@app), notice: "Integration was successfully created."
    else
      redirect_to app_integrations_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  def build_artifact_channels
    @target = params[:target]
    with_production = params[:with_production]&.to_boolean
    @build_channels = Integration.find_build_channels(params[:integration_id], with_production:)

    respond_to(&:turbo_stream)
  end

  def destroy
    @integration = @app.integrations.find(params[:id])

    unless @integration.disconnectable?
      redirect_back fallback_location: root_path,
        flash: {error: "Cannot disconnect since the integration is currently being used by a release or in a step."}
      return
    end

    if @integration.disconnect
      redirect_to app_integrations_path(@app), notice: "Integration was successfully disconnected."
    else
      redirect_to app_integrations_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_integrations_by_categories
    @integrations_by_categories = Integration.by_categories_for(@app)
  end

  def set_integration
    @integration = @app.integrations.new(integrations_only_params)
  end

  def set_providable
    @integration.providable = providable_type.constantize.new(integration: @integration)
    set_providable_params
  end

  def set_providable_params
    @integration.providable.assign_attributes(providable_params)
  end

  def set_tab_configuration
    @tab_configuration = [
      [1, "General", edit_app_path(@app), "v2/cog.svg"],
      [2, "Integrations", app_integrations_path(@app), "v2/blocks.svg"],
      [3, "App Variants", app_app_config_app_variants_path(@app), "dna.svg"]
    ]
  end

  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:type]
      ).merge(current_user:)
  end

  def integrations_only_params
    integration_params.except(:providable)
  end

  def providable_params
    {}
  end

  def providable_type
    integration_params[:providable][:type]
  end

  def index_path
    app_integrations_path(@app)
  end
end
