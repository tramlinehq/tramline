class IntegrationListeners::JiraController < IntegrationListenerController
  using RefinedString

  INTEGRATION_CREATE_ERROR = "Failed to create the integration, please try again."

  def callback
    unless valid_state?
      redirect_to app_path(state_app), alert: INTEGRATION_CREATE_ERROR
      return
    end

    begin
      @integration = state_app.integrations.build(integration_params)
      @integration.providable = build_providable

      if @integration.providable.complete_access
        @integration.save!
        redirect_to app_path(state_app),
          notice: t("integrations.project_management.jira.integration_created")
      else
        @resources = @integration.providable.available_resources

        if @resources.blank?
          redirect_to app_integrations_path(state_app),
            alert: t("integrations.project_management.jira.no_organization")
          return
        end

        render "jira_integration/select_organization"
      end
    rescue => e
      Rails.logger.error("Failed to create Jira integration: #{e.message}")
      redirect_to app_integrations_path(state_app),
        alert: INTEGRATION_CREATE_ERROR
    end
  end

  def set_organization
    @integration = state_app.integrations.build(integration_params)
    @integration.providable = build_providable
    @integration.providable.cloud_id = params[:cloud_id]
    @integration.providable.code = params[:code]

    if @integration.save!
      @integration.providable.setup
      redirect_to app_path(@integration.integrable),
        notice: t("integrations.project_management.jira.integration_created")
    else
      @resources = @integration.providable.available_resources
      render "jira_integration/select_organization"
    end
  rescue => e
    Rails.logger.error("Failed to create Jira integration: #{e.message}")
    redirect_to app_integrations_path(state_app),
      alert: INTEGRATION_CREATE_ERROR
  end

  protected

  def providable_params
    super.merge(
      code: code,
      callback_url: callback_url
    )
  end

  private

  def callback_url
    host = request.host_with_port
    Rails.application.routes.url_helpers.jira_callback_url(
      host: host,
      protocol: request.protocol.gsub("://", "")
    )
  end

  def state
    @state ||= begin
      cleaned_state = params[:state].tr(" ", "+")
      JSON.parse(cleaned_state.decode).with_indifferent_access
    rescue ActiveSupport::MessageEncryptor::InvalidMessage => e
      Rails.logger.error "Invalid state parameter: #{e.message}"
      {}
    end
  end

  def error?
    params[:error].present? || state.empty?
  end

  def state_app
    @state_app ||= App.find(state[:app_id])
  end
end
