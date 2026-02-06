class AppVariantIntegrations::GoogleFirebaseController < AppVariantIntegrationsController
  include JsonKeyProvidable

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
      @integrations = @app_variant.integrations.connected
      set_app_config_tabs
      render :index, status: :unprocessable_entity
    else
      super
    end
  end

  def providable_params
    super.merge(integration_params[:providable].slice(:project_number))
  end
end
