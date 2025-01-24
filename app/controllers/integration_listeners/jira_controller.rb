class IntegrationListeners::JiraController < IntegrationListenerController
  using RefinedString

  def callback
    unless valid_state?
      redirect_to app_path(state_app), alert: INTEGRATION_CREATE_ERROR
      return
    end

    begin
      @integration = state_app.integrations.build(integration_params)
      @integration.providable = build_providable

      if @integration.providable.complete_access && @integration.save
        redirect_to app_path(state_app), notice: t("integrations.project_management.jira.integration_created")
      else
        @resources = @integration.providable.available_resources

        if @resources.blank?
          redirect_to app_integrations_path(state_app), alert: t("integrations.project_management.jira.no_organization")
          return
        end

        render "jira_integration/select_organization"
      end
    rescue => e
      Rails.logger.error(e)
      redirect_to app_integrations_path(state_app), alert: INTEGRATION_CREATE_ERROR
    end
  end

  protected

  def providable_params
    super.merge(
      code: code,
      cloud_id: params[:cloud_id]
    )
  end

  private

  def error?
    params[:error].present? || state.empty?
  end
end
