class IntegrationListenerController < SignedInApplicationController
  using RefinedString

  def callback
    return unless valid_state?
    @integration = state_app.integrations.new(integration_params)

    @integration
      .decide
      .complete_access

    respond_to do |format|
      if @integration.save
        format.html { redirect_to app_path, notice: "Integration was successfully created." }
        format.json { render :show, status: :created, location: state_app }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: state_app.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def state
    @state ||= JSON.parse(params[:state].decode).with_indifferent_access
  end

  def installation_id
    params[:installation_id]
  end

  def valid_state?
    state_user.present? && state_organization.present? && state_app.present?
  end

  def integration_params
    {
      installation_id: installation_id,
      category: state_integration_category,
      provider: state_integration_provider,
      status: Integration::DEFAULT_CONNECT_STATUS[state_integration_category],
      code: code
    }
  end

  def state_user
    @state_user ||= Accounts::User.find(state[:user_id])
  end

  def state_organization
    @state_organization ||= @state_user.organizations.find(state[:organization_id])
  end

  def state_app
    @state_app = @state_organization.apps.find(state[:app_id])
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

  def app_path
    accounts_organization_app_path(current_organization, state_app)
  end
end
