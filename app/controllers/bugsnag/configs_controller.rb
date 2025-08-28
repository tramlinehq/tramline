class Bugsnag::ConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[update]
  before_action :set_bugsnag_integration, only: %i[edit update]
  around_action :set_time_zone

  BUGSNAG_CONFIG_PARAMS = [:bugsnag_ios_project_id, :bugsnag_ios_release_stage, :bugsnag_android_project_id, :bugsnag_android_release_stage].freeze

  def edit
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame do
          set_monitoring_projects if @integration.further_setup?
          render "bugsnag/configs/edit"
        end
      end

      format.turbo_stream do
        set_monitoring_projects if @integration.further_setup?
        render "bugsnag/configs/edit"
      end
    end
  end

  def update
    if @integration.update(bugsnag_config_params)
      redirect_to app_path(@app), notice: "Bugsnag configuration was successfully updated."
    else
      redirect_back fallback_location: edit_app_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_bugsnag_integration
    @integration = @app.integrations.monitoring.first&.providable
    unless @integration.is_a?(BugsnagIntegration)
      redirect_to app_path(@app), flash: {error: "Bugsnag integration not found."}
    end
  end

  def bugsnag_config_params
    parsed_params = params
      .require(:bugsnag_integration)
      .permit(*BUGSNAG_CONFIG_PARAMS)

    config = {}

    if parsed_params[:bugsnag_ios_release_stage].present?
      config[:ios_config] = {
        project_id: parsed_params[:bugsnag_ios_project_id]&.safe_json_parse,
        release_stage: parsed_params[:bugsnag_ios_release_stage]
      }
    end

    if parsed_params[:bugsnag_android_release_stage].present?
      config[:android_config] = {
        project_id: parsed_params[:bugsnag_android_project_id]&.safe_json_parse,
        release_stage: parsed_params[:bugsnag_android_release_stage]
      }
    end

    config
  end

  def set_monitoring_projects
    @monitoring_projects = @app.monitoring_provider.setup
  end
end