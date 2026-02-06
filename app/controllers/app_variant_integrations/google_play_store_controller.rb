class AppVariantIntegrations::GooglePlayStoreController < AppVariantIntegrationsController
  include JsonKeyProvidable

  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:json_key_file, :type]
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
end
