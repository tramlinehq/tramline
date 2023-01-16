class AppConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_app, only: %i[edit update]
  before_action :set_ci_cd_projects, only: %i[edit]

  def edit
    @config = AppConfig.find_or_initialize_by(app: @app)
    @code_repositories = @app.vcs_provider.repos
    @notification_channels = @app.notification_provider.channels if @app.notifications_set_up?
    @ci_cd_provider_name = @app.ci_cd_provider.display
  end

  def update
    @config = AppConfig.find_or_initialize_by(app: @app)

    if @config.update(parsed_app_config_params)
      redirect_to app_path(@app), notice: "App Config was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def app_config_params
    params
      .require(:app_config)
      .permit(
        :code_repository,
        :notification_channel,
        :project_id
      )
  end

  def parsed_app_config_params
    app_config_params
      .merge(code_repository: app_config_params[:code_repository]&.safe_json_parse)
      .merge(notification_channel: app_config_params[:notification_channel]&.safe_json_parse)
      .merge(project_id: app_config_params[:project_id]&.safe_json_parse)
  end

  def set_ci_cd_projects
    if @app.ci_cd_provider.belongs_to_project?
      @ci_cd_projects = @app.ci_cd_provider.list_apps
    end
  end
end
