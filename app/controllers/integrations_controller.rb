class IntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[connect create]
  before_action :set_integration, only: %i[connect create]
  before_action :set_providable, only: %i[connect create]

  def connect
    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def index
    set_integrations_by_categories
    @tab_configuration = [
      [1, "General", edit_app_path(@app), "v2/cog.svg"],
      [2, "Integrations", app_integrations_path(@app), "v2/blocks.svg"],
      [3, "App Variants", app_app_config_app_variants_path(@app), "dna.svg"]
    ]
    respond_to do |format|
      format.html do |variant|
        variant.none
        variant.turbo_frame
      end
    end
  end

  def create
    if @integration.save
      redirect_to app_path(@app), notice: "Integration was successfully created."
    else
      set_integrations_by_categories
      render :index, status: :unprocessable_entity
    end
  end

  def build_artifact_channels
    @target = params[:target]
    with_production = params[:with_production]&.to_boolean
    @build_channels = Integration.find_build_channels(params[:integration_id], with_production:)

    respond_to(&:turbo_stream)
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
