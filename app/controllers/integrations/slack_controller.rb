class Integrations::SlackController < IntegrationsController
  before_action :require_write_access!, only: %i[refresh_channels]
  before_action :set_app, only: %i[refresh_channels]

  def refresh_channels
    slack_integration.fetch_channels
    redirect_to app_app_config_path(@app), notice: "We are refreshing your Slack channels. They will update shortly."
  end

  private

  def slack_integration
    @slack_integration ||= SlackIntegration.find(params[:id])
  end
end
