class Integrations::GoogleFirebaseController < IntegrationsController
  before_action :require_write_access!, only: %i[refresh_channels]
  before_action :set_app, only: %i[refresh_channels]

  def refresh_channels
    RefreshFADChannelsJob.perform_later(fad_integration.id)
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
      render :index, status: :unprocessable_entity
    else
      super
    end
  end

  def providable_params
    super
      .merge(json_key: json_key_file.read)
      .merge(integration_params[:providable].slice(:project_number))
  end

  def providable_params_errors
    @providable_params_errors ||= Validators::KeyFileValidator.validate(json_key_file).errors
  end

  def json_key_file
    @json_key_file ||= integration_params[:providable][:json_key_file]
  end

  def fad_integration
    @fad_integration ||= GoogleFirebaseIntegration.find(params[:id])
  end
end
