class VersionControl::ConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[update]
  before_action :set_vcs_integration, only: %i[edit update]
  around_action :set_time_zone

  def edit
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame do
          set_code_repositories if @integration.further_setup?
          render "version_control/configs/edit"
        end
      end

      format.turbo_stream do
        set_code_repositories if @integration.further_setup?
        render "version_control/configs/edit"
      end
    end
  end

  def update
    if @integration.update(vcs_config_params)
      redirect_to app_path(@app), notice: "Version control configuration was successfully updated."
    else
      redirect_back fallback_location: edit_app_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_vcs_integration
    @integration = @app.vcs_provider
    unless @integration
      redirect_to app_path(@app), flash: {error: "Version control integration not found."}
    end
  end

  def vcs_config_params
    case @integration.class.name
    when 'GithubIntegration', 'GitlabIntegration'
      params
        .require(@integration.class.name.underscore.to_sym)
        .permit(:repository_config)
        .merge(repository_config: params[@integration.class.name.underscore.to_sym][:repository_config]&.safe_json_parse)
        .compact
    when 'BitbucketIntegration'
      params
        .require(:bitbucket_integration)
        .permit(:repository_config, :workspace)
        .merge(
          repository_config: params[:bitbucket_integration][:repository_config]&.safe_json_parse
        )
        .compact
    else
      {}
    end
  end

  def set_code_repositories
    @workspaces = @app.vcs_provider.workspaces || []
    workspace = params[:workspace] || @workspaces.first
    @code_repositories = @app.vcs_provider.repos(workspace)
  end
end