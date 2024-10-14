class Integrations::AppStoreController < IntegrationsController
  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:key_id, :issuer_id, :p8_key_file, :type]
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
    super
      .merge(p8_key: p8_key_file.read)
      .merge(integration_params[:providable].slice(:key_id, :issuer_id))
  end

  def providable_params_errors
    @providable_params_errors ||= Validators::KeyFileValidator.validate(p8_key_file).errors
  end

  def p8_key_file
    @p8_key_file ||= integration_params[:providable][:p8_key_file]
  end
end
