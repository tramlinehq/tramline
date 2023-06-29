class AppConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_app, only: %i[edit update]
  before_action :require_integration_setup, only: %i[edit update]
  before_action :set_app_config, only: %i[edit update]
  before_action :set_code_repositories, only: %i[edit update]
  before_action :set_notification_channels, only: %i[edit update]
  before_action :set_ci_cd_projects, only: %i[edit]
  before_action :set_firebase_apps, only: %i[edit update]

  def edit
    @ci_cd_provider_name = @app.ci_cd_provider.display
  end

  def update
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

  def set_app_config
    @config = AppConfig.find_or_initialize_by(app: @app)
  end

  def app_config_params
    params
      .require(:app_config)
      .permit(
        :code_repository,
        :notification_channel,
        :project_id,
        :firebase_android_config,
        :firebase_ios_config
      )
  end

  def parsed_app_config_params
    app_config_params
      .merge(code_repository: app_config_params[:code_repository]&.safe_json_parse)
      .merge(notification_channel: app_config_params[:notification_channel]&.safe_json_parse)
      .merge(project_id: app_config_params[:project_id]&.safe_json_parse)
      .merge(firebase_ios_config: app_config_params[:firebase_ios_config]&.safe_json_parse)
      .merge(firebase_android_config: app_config_params[:firebase_android_config]&.safe_json_parse)
      .compact
  end

  def set_ci_cd_projects
    if @app.ci_cd_provider.belongs_to_project?
      @ci_cd_projects = @app.ci_cd_provider.list_apps
    end
  end

  def set_firebase_apps
    if @app.integrations.google_firebase_integrations.any?
      if @app.cross_platform?
        @firebase_android_apps = @app.integrations.google_firebase_integrations.first.providable.list_apps(platform: "android")
        @firebase_ios_apps = @app.integrations.google_firebase_integrations.first.providable.list_apps(platform: "ios")
      elsif @app.android?
        @firebase_android_apps = @app.integrations.google_firebase_integrations.first.providable.list_apps(platform: "android")
        @firebase_ios_apps = nil
      elsif @app.ios?
        @firebase_android_apps = nil
        @firebase_ios_apps = @app.integrations.google_firebase_integrations.first.providable.list_apps(platform: "ios")
      end
    end
  end

  def set_code_repositories
    @code_repositories = @app.vcs_provider.repos
  end

  def set_notification_channels
    @notification_channels = @app.notification_provider.channels if @app.notifications_set_up?
  end

  def require_integration_setup
    unless @app.app_setup_instructions[:app_config][:visible]
      redirect_to app_path(@app), flash: {notice: "Finish the integration setup before configuring the app."}
    end
  end
end
