class Integrations::GooglePlayStoreController < IntegrationsController
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
      set_integrations_by_categories
      render :index, status: :unprocessable_entity
    else
      super
    end
  end

  def providable_params
    super.merge(json_key: json_key_file.read)
  end

  def providable_params_errors
    @providable_params_errors ||= Validators::KeyFileValidator.validate(json_key_file).errors
  end

  def json_key_file
    @json_key_file ||= integration_params[:providable][:json_key_file]
  end
end
