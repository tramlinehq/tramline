class Monitoring::SentryConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_sentry_integration

  def edit
    set_monitoring_projects

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @sentry_integration.update(parsed_sentry_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @sentry_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_sentry_integration
    @sentry_integration = @app.monitoring_provider
    unless @sentry_integration.is_a?(SentryIntegration)
      redirect_to app_integrations_path(@app), flash: {error: "Monitoring integration not found."}
    end
  end

  def set_monitoring_projects
    @monitoring_projects = @sentry_integration.setup
  end

  def parsed_sentry_config_params
    sentry_config_params = params.require(:sentry_integration)
      .permit(
        :ios_project,
        :ios_environment,
        :ios_organization_slug,
        :android_project,
        :android_environment,
        :android_organization_slug
      )
    sentry_config_params.merge(sentry_config(sentry_config_params))
  end

  def sentry_config(config_params)
    config = {}

    if config_params[:ios_environment].present?
      config[:ios_config] = {
        project: config_params[:ios_project]&.safe_json_parse,
        environment: config_params[:ios_environment],
        organization_slug: config_params[:ios_organization_slug]
      }
    end

    if config_params[:android_environment].present?
      config[:android_config] = {
        project: config_params[:android_project]&.safe_json_parse,
        environment: config_params[:android_environment],
        organization_slug: config_params[:android_organization_slug]
      }
    end

    config
  end
end
