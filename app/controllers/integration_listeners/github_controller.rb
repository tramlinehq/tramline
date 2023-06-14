class IntegrationListeners::GithubController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  def providable_params
    super.merge(installation_id:)
  end

  def events
    case event_type
    when "push"
      handle_push
    when "ping"
      handle_ping
    else
      head :ok
    end
  end

  def handle_ping
    head :accepted
  end

  def handle_push
    response = WebhookHandlers::Push.process(train, params)

    Rails.logger.debug response.body
    head response.status
  end

  private

  def event_type
    request.headers["HTTP_X_GITHUB_EVENT"]
  end

  def train
    @train ||= Train.find(params[:train_id])
  end
end
