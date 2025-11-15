class CiCd::BitriseConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_bitrise_integration

  def edit
    set_ci_cd_projects

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @bitrise_integration.update(parsed_bitrise_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @bitrise_integration.errors.full_messages.to_sentence}
    end
  end

  private


  def set_bitrise_integration
    @bitrise_integration = @app.ci_cd_provider
    unless @bitrise_integration.is_a?(BitriseIntegration)
      redirect_to app_integrations_path(@app), flash: {error: "CI/CD integration not found."}
    end
  end

  def set_ci_cd_projects
    @ci_cd_apps = @bitrise_integration.setup
    @project_config = @bitrise_integration.project_config
  end

  def parsed_bitrise_config_params
    bitrise_config_params =
      params.require(:bitrise_integration).permit(:project_config)
    bitrise_config_params
      .merge(project_config: bitrise_config_params[:project_config]&.safe_json_parse)
  end
end
