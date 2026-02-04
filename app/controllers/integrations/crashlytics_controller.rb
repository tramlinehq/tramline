class Integrations::CrashlyticsController < IntegrationsController
  include JsonKeyProvidable

  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:project_number, :json_key_file, :type]
      ).merge(current_user:)
  end

  def providable_params
    super.merge(integration_params[:providable].slice(:project_number))
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
end
