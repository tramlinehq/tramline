class Bitrise::ConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[update]
  before_action :set_bitrise_integration, only: %i[edit update]
  around_action :set_time_zone

  def edit
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame do
          set_ci_cd_projects if @integration.further_setup?
          render "bitrise/configs/edit"
        end
      end

      format.turbo_stream do
        set_ci_cd_projects if @integration.further_setup?
        render "bitrise/configs/edit"
      end
    end
  end

  def update
    if @integration.update(bitrise_config_params)
      redirect_to app_path(@app), notice: "Bitrise configuration was successfully updated."
    else
      redirect_back fallback_location: edit_app_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_bitrise_integration
    @integration = @app.ci_cd_provider
    unless @integration.is_a?(BitriseIntegration)
      redirect_to app_path(@app), flash: {error: "Bitrise integration not found."}
    end
  end

  def bitrise_config_params
    params
      .require(:bitrise_integration)
      .permit(:project_config)
      .merge(project_config: params[:bitrise_integration][:project_config]&.safe_json_parse)
      .compact
  end

  def set_ci_cd_projects
    @ci_cd_apps = @app.ci_cd_provider.setup
  end
end