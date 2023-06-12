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
    if train
      response = WebhookHandlers::Push.process(train, params)
    elsif train_group
      response = WebhookHandlers::Push.process(train_group, params)
    else
      Rails.logger.debug "No train found to handle event"
      return head :ok
    end

    Rails.logger.debug response.body
    head response.status
  end

  private

  def event_type
    request.headers["HTTP_X_GITHUB_EVENT"]
  end

  def train
    @train ||= Releases::Train.where(id: params[:train_id]).first
  end

  def train_group
    @train_group ||= Releases::TrainGroup.where(id: params[:train_id]).first
  end
end
