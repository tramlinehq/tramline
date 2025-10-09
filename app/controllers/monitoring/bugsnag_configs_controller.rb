class Monitoring::BugsnagConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_app
  before_action :set_bugsnag_integration
  around_action :set_time_zone

  def edit
    set_monitoring_projects

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @bugsnag_integration.update(parsed_bugsnag_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @bugsnag_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_bugsnag_integration
    @bugsnag_integration = @app.monitoring_provider
    unless @bugsnag_integration.is_a?(BugsnagIntegration)
      redirect_to app_integrations_path(@app), flash: {error: "Monitoring integration not found."}
    end
  end

  def set_monitoring_projects
    @monitoring_projects = @bugsnag_integration.setup
  end

  def parsed_bugsnag_config_params
    bugsnag_config_params = params.require(:bugsnag_integration)
      .permit(
        :ios_project_id,
        :ios_release_stage,
        :android_project_id,
        :android_release_stage
      )
    bugsnag_config_params.merge(bugsnag_config(bugsnag_config_params))
  end

  def bugsnag_config(config_params)
    config = {}

    if config_params[:ios_release_stage].present?
      config[:ios_config] = {
        project_id: config_params[:ios_project_id]&.safe_json_parse,
        release_stage: config_params[:ios_release_stage]
      }
    end

    if config_params[:android_release_stage].present?
      config[:android_config] = {
        project_id: config_params[:android_project_id]&.safe_json_parse,
        release_stage: config_params[:android_release_stage]
      }
    end

    config
  end
end
