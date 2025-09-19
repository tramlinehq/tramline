class VersionControl::GithubConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_app
  before_action :set_github_integration
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
    if @github_integration.update(parsed_github_config_params)
      redirect_to app_integrations_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @github_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_github_integration
    @github_integration = @app.vcs_provider
    unless @github_integration
      redirect_to app_integrations_path(@app), flash: {error: "Version control integration not found."}
    end
  end

  def set_code_repositories
    @code_repositories = @github_integration.repos
  end

  def parsed_github_config_params
    github_config_params = params.require(:github_integration)
      .permit(:repository_config)
    github_config_params.merge(
      repository_config: github_config_params[:repository_config]&.safe_json_parse
    )
  end
end
