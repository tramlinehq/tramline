class Accounts::AppConfigsController < SignedInApplicationController
  using RefinedString
  before_action :set_app, only: %i[edit update]

  def edit
    @config = AppConfig.find_or_initialize_by(app: @app)
    @code_repositories = @app.vcs_provider.repos
    @notification_channels = @app.notification_provider.channels
  end

  def update
    @config = AppConfig.find_or_initialize_by(app: @app)

    if @config.update(parsed_app_config_params)
      redirect_to accounts_organization_app_path(current_organization, @app),
                  notice: "App Config was successfully updated."
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
        :working_branch,
        :notification_channel
      )
  end

  def parsed_app_config_params
    app_config_params
      .merge(code_repository: app_config_params[:code_repository]&.safe_json_parse)
      .merge(notification_channel: app_config_params[:notification_channel]&.safe_json_parse)
  end
end
