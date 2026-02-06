class Integrations::GoogleFirebaseController < IntegrationsController
  include JsonKeyProvidable

  before_action :require_write_access!, only: %i[refresh_channels]

  def refresh_channels
    fad_integration.fetch_channels
    redirect_to app_app_config_path(@app),
      notice: "We are refreshing your Firebase App Distribution channels. They will update shortly."
  end

  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:json_key_file, :type, :project_number]
      ).merge(current_user:)
  end

  def set_providable_params
    if providable_params_errors.present?
      flash.now[:error] = providable_params_errors.first
      set_integrations_by_categories
      set_app_config_tabs
      render :index, status: :unprocessable_entity
    else
      super
    end
  end

  def providable_params
    super.merge(integration_params[:providable].slice(:project_number))
  end

  def fad_integration
    @fad_integration ||= GoogleFirebaseIntegration.find(params[:id])
  end
end
