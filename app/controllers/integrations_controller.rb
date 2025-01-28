class IntegrationsController < SignedInApplicationController
  using RefinedString
  include Tabbable

  before_action :require_write_access!, only: %i[connect create build_artifact_channels destroy]
  before_action :set_app_config_tabs, only: %i[index]
  before_action :set_integration, only: %i[connect create reuse]
  before_action :set_existing_integration, only: %i[reuse]
  before_action :set_providable, only: %i[connect create]

  def connect
    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def index
    @pre_open_category = Integration.categories[params[:integration_category]]
    set_integrations_by_categories
  end

  def reuse
    return redirect_to app_integrations_path(@app), alert: "Integration not found or not connected." unless @existing_integration&.connected?
    new_integration = initiate_integration(@existing_integration)
    if new_integration.save
      redirect_to app_integrations_path(@app), notice: "#{@existing_integration.providable_type} integration reused successfully."
    else
      redirect_to app_integrations_path(@app), flash: {error: new_integration.errors.full_messages.to_sentence}
    end
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

  def initiate_integration(existing_integration)
    @app.integrations.build(
      category: @integration.category,
      status: Integration.statuses[:connected],
      metadata: existing_integration.metadata,
      providable: existing_integration.providable.dup
    )
  end

  def set_integrations_by_categories
    @integrations_by_categories = Integration.by_categories_for(@app)
  end

  def set_integration
    @integration = @app.integrations.new(integrations_only_params)
  end

  def set_existing_integration
    @existing_integration = Integration.find_by(id: params[:integration][:existing_integration_id])
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
