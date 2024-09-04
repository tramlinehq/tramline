class IntegrationListeners::BitbucketController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  def providable_params
    super.merge(code: code)
  end

  # TODO: what do we want to do when these events come in
  def events
    case event_type&.split(":")&.first
    when "repo"
      handle_push
    when "pull_request"
      handle_pull_request
    else
      head :ok
    end
  end

  private

  def handle_ping
  end

  def handle_push
  end

  def handle_pull_request
  end

  def event_type
    request.headers["X-Event-Key"]
  end

  def train
  end

  def pull_request_params
  end

  def push_params
  end
end
