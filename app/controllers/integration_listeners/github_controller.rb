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
    Webhooks::ProcessPushWebhookJob.perform_async(params[:train_id], push_params.to_h)
    head :accepted
  end

  def handle_pull_request
    Webhooks::ProcessPullRequestWebhookJob.perform_async(params[:train_id], pull_request_params.to_h)
    head :accepted
  end

  def event_type
    request.headers["HTTP_X_GITHUB_EVENT"]
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
        :merge_commit_sha,
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
