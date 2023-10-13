class Integrations::BugsnagController < IntegrationsController
  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:access_token, :type]
      ).merge(current_user:)
  end

  def providable_params
    super.merge(access_token: access_token)
  end

  def access_token
    integration_params[:providable][:access_token]
  end
end
