class VersionControl::GitlabConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_app
  before_action :set_gitlab_integration
  around_action :set_time_zone

  def edit
    set_code_repositories

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @gitlab_integration.update(parsed_gitlab_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @gitlab_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_gitlab_integration
    @gitlab_integration = @app.vcs_provider
    unless @gitlab_integration
      redirect_to app_integrations_path(@app), flash: {error: "Version control integration not found."}
    end
  end

  def set_code_repositories
    @code_repositories = @gitlab_integration.repos
  end

  def parsed_gitlab_config_params
    gitlab_config_params = params.require(:gitlab_integration)
      .permit(:repository_config)
    gitlab_config_params.merge(
      repository_config: gitlab_config_params[:repository_config]&.safe_json_parse
    )
  end
end
