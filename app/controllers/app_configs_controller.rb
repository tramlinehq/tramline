class AppConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_app, only: %i[edit update]
  before_action :require_integration_setup, only: %i[edit update]
  before_action :set_app_config, only: %i[edit update]
  before_action :set_code_repositories, only: %i[edit update]
  before_action :set_notification_channels, only: %i[edit update]
  before_action :set_ci_cd_projects, only: %i[edit update], if: -> { @config.further_ci_cd_setup? }
  before_action :set_firebase_apps, only: %i[edit update], if: -> { @config.further_build_channel_setup? }

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
        :bitrise_project_id,
        :firebase_android_config,
        :firebase_ios_config
      )
  end

  def parsed_app_config_params
    app_config_params
      .merge(code_repository: app_config_params[:code_repository]&.safe_json_parse)
      .merge(notification_channel: app_config_params[:notification_channel]&.safe_json_parse)
      .merge(bitrise_project_id: app_config_params[:bitrise_project_id]&.safe_json_parse)
      .merge(firebase_ios_config: app_config_params[:firebase_ios_config]&.safe_json_parse)
      .merge(firebase_android_config: app_config_params[:firebase_android_config]&.safe_json_parse)
      .compact
  end

  def set_ci_cd_projects
    @ci_cd_apps = @app.ci_cd_provider.setup
  end

  def set_firebase_apps
    config = @app.integrations.firebase_build_channel_provider.setup
    @firebase_android_apps, @firebase_ios_apps = config[:android], config[:ios]
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
