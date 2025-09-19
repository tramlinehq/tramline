class CiCd::BitriseConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_app
  before_action :set_bitrise_integration
  around_action :set_time_zone

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
      redirect_to app_integrations_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @bitrise_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_bitrise_integration
    @bitrise_integration = @app.ci_cd_provider
    unless @bitrise_integration
      redirect_to app_integrations_path(@app), flash: {error: "CI/CD integration not found."}
    end
  end

  def set_ci_cd_projects
    @ci_cd_apps = @bitrise_integration.setup
    @project_config = @bitrise_integration.project_config
  end

  def parsed_bitrise_config_params
    bitrise_config_params = params.require(:bitrise_integration)
      .permit(:project_config)
    bitrise_config_params.merge(
      project_config: bitrise_config_params[:project_config]&.safe_json_parse
    )
  end
end
