class Integrations::TeamcityController < IntegrationsController
  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [
          :server_url,
          :access_token,
          :cf_access_client_id,
          :cf_access_client_secret,
          :type
        ]
      ).merge(current_user:)
  end

  def providable_params
    super.merge(
      server_url: server_url,
      access_token: access_token,
      cf_access_client_id: cf_access_client_id,
      cf_access_client_secret: cf_access_client_secret
    )
  end

  def server_url
    integration_params.dig(:providable, :server_url)
  end

  def access_token
    integration_params.dig(:providable, :access_token)
  end

  def cf_access_client_id
    integration_params.dig(:providable, :cf_access_client_id)
  end

  def cf_access_client_secret
    integration_params.dig(:providable, :cf_access_client_secret)
  end
end
