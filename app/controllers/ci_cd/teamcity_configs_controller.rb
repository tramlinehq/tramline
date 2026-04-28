class CiCd::TeamcityConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_teamcity_integration

  def edit
    set_ci_cd_projects

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @teamcity_integration.update(parsed_teamcity_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @teamcity_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_teamcity_integration
    @teamcity_integration = @app.ci_cd_provider
    unless @teamcity_integration.is_a?(TeamcityIntegration)
      redirect_to app_integrations_path(@app), flash: {error: "CI/CD integration not found."}
    end
  end

  def set_ci_cd_projects
    @ci_cd_projects = @teamcity_integration.setup
    @project_config = @teamcity_integration.project_config
  end

  def parsed_teamcity_config_params
    teamcity_config_params =
      params.require(:teamcity_integration).permit(:project_config)
    teamcity_config_params
      .merge(project_config: teamcity_config_params[:project_config]&.safe_json_parse)
  end
end
