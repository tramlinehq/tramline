class IntegrationListeners::LinearController < IntegrationListenerController
  using RefinedString

  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]
  skip_before_action :require_organization!, only: [:events]

  def callback
    unless valid_state?
      redirect_to app_path(state_app), alert: INTEGRATION_CREATE_ERROR
      return
    end

    begin
      @integration = state_app.integrations.build(integration_params)
      @integration.providable = build_providable

      if @integration.providable.complete_access && @integration.save
        redirect_to app_path(state_app), notice: t("integrations.project_management.linear.integration_created")
      else
        @organizations = @integration.providable.available_organizations

        if @organizations.blank?
          redirect_to app_integrations_path(state_app), alert: t("integrations.project_management.linear.no_organization")
        else
          render "linear_integration/select_organization"
        end
      end
    rescue => e
      elog(e, level: :error)
      redirect_to app_integrations_path(state_app), alert: INTEGRATION_CREATE_ERROR
    end
  end

  def events
    Rails.logger.debug { "Got a webhook from Linear!" }
    head :accepted
  end

  protected

  def providable_params
    super.merge(
      code: code,
      organization_id: params[:organization_id]
    )
  end

  private

  def error?
    params[:error].present? || state.empty?
  end
end
