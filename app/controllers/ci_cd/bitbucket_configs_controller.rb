class CiCd::BitbucketConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_app
  before_action :set_bitbucket_integration
  around_action :set_time_zone

  def edit
    set_code_repositories

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
      format.turbo_stream { render :edit }
    end
  end

  def update
    if @bitbucket_integration.update(parsed_bitbucket_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @bitbucket_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_bitbucket_integration
    @bitbucket_integration = @app.ci_cd_provider
    unless @bitbucket_integration
      redirect_to app_integrations_path(@app), flash: {error: "CI/CD integration not found."}
    end
  end

  def set_code_repositories
    @workspaces = @bitbucket_integration.workspaces || []
    workspace = params[:workspace] || @workspaces.first
    @code_repositories = @bitbucket_integration.repos(workspace)
  end

  def parsed_bitbucket_config_params
    bitbucket_config_params = params.require(:bitbucket_integration)
      .permit(:repository_config, :workspace)
    bitbucket_config_params.merge(
      repository_config: bitbucket_config_params[:repository_config]&.safe_json_parse
    )
  end
end
