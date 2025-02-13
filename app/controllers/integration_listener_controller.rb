class IntegrationListenerController < SignedInApplicationController
  using RefinedString
  before_action :require_write_access!, only: %i[callback]
  INTEGRATION_CREATE_ERROR = "Failed to create the integration, please try again."

  def callback
    unless valid_state?
      redirect_to app_path(state_app), alert: INTEGRATION_CREATE_ERROR
      return
    end

    @integration = state_app.integrations.new(integration_params)
    @integration.providable = build_providable

    if @integration.save
      redirect_to app_path(state_app), notice: "Integration was successfully created."
    else
      redirect_to app_integrations_path(state_app), alert: INTEGRATION_CREATE_ERROR
    end
  rescue => e
    Rails.logger.error("Failed to create integration: #{e.message}")
    redirect_to app_integrations_path(state_app), alert: INTEGRATION_CREATE_ERROR
  end

  protected

  def providable_params
    {integration: @integration}
  end

  private

  def state
    @state ||=
      begin
        JSON.parse(params[:state].tr(" ", "+").decode).with_indifferent_access
      rescue ActiveSupport::MessageEncryptor::InvalidMessage => e
        Rails.logger.error(e)
        {}
      end
  end

  def installation_id
    params[:installation_id]
  end

  def valid_state?
    state_user.present? && state_organization.present? && state_app.present? && !error?
  end

  def integration_params
    {
      category: state_integration_category,
      status: Integration::DEFAULT_CONNECT_STATUS
    }
  end

  def build_providable
    state_integration_provider.constantize.new(providable_params)
  end

  def state_user
    @state_user ||= Accounts::User.find(state[:user_id])
  end

  def state_organization
    @state_organization ||= @state_user.organizations.find(state[:organization_id])
  end

  def state_app
    @state_app ||= @state_organization.apps.find(state[:app_id])
    @app = @state_app
  end

  def state_integration_category
    state[:integration_category]
  end

  def state_integration_provider
    state[:integration_provider]
  end

  def code
    params[:code]
  end

  def error?
    params[:error] == "access_denied"
  end
end
