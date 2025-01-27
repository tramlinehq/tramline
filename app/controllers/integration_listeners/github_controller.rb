class IntegrationListeners::GithubController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]
  skip_before_action :require_organization!, only: [:events]

  def providable_params
    super.merge(installation_id:)
  end

  def events
    case event_type
    when "push"
      handle_push
    when "ping"
      handle_ping
    when "pull_request"
      handle_pull_request
    else
      head :ok
    end
  end

  private

  def handle_ping
    head :accepted
  end

  def handle_push
    result = Action.process_push_webhook(train, push_params)
    response = result.ok? ? result.value! : Response.new(:unprocessable_entity, "Error processing push")
    Rails.logger.error { result.error }
    head response.status
  end

  def handle_pull_request
    result = Action.process_pull_request_webhook(train, pull_request_params)
    response = result.ok? ? result.value! : Response.new(:unprocessable_entity, "Error processing pull request")
    Rails.logger.debug { response.body }
    head response.status
  end

  def event_type
    request.headers["HTTP_X_GITHUB_EVENT"]
  end

  def train
    @train ||= Train.find(params[:train_id])
  end

  def pull_request_params
    params.permit(
      repository: [:full_name, :name],
      pull_request: [
        :number,
        :title,
        :body,
        :url,
        :state,
        :created_at,
        :closed_at,
        :id,
        :html_url,
        base: [:ref],
        head: [:ref, repo: [:full_name]],
        labels: [:id, :name, :color, :description]
      ]
    )
  end

  def push_params
    params.permit(
      :ref,
      repository: [:full_name, :name],
      head_commit: [
        :id,
        :message,
        :timestamp,
        :url,
        author: [:name, :email, :username],
        committer: [:name, :email, :username]
      ],
      commits: [
        :id,
        :message,
        :timestamp,
        :url,
        author: [:name, :email, :username],
        committer: [:name, :email, :username]
      ]
    )
  end
end
