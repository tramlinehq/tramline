class IntegrationListeners::GitlabController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  def providable_params
    super.merge(code: code)
  end

  def events
    case event_type
    when "push"
      handle_push
    when "ping"
      handle_ping
    when "merge_request"
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
    response =
      if train.product_v2?
        Action.process_push_webhook!(train, push_params)
      else
        WebhookHandlers::Push.process(train, push_params)
      end

    Rails.logger.debug response.body
    head response.status
  end

  def handle_pull_request
    response =
      if train.product_v2?
        Action.process_pull_request_webhook!(train, pull_request_params)
      else
        WebhookHandlers::PullRequest.process(train, pull_request_params)
      end

    Rails.logger.debug response.body
    head response.status
  end

  def event_type
    params[:object_kind]
  end

  def train
    @train ||= Train.find(params[:train_id])
  end

  def push_params
    params.permit(
      :ref,
      :checkout_sha,
      project: [:path_with_namespace],
      commits: [:id, :message, :title, :timestamp, :url, author: [:name, :email]]
    )
  end

  def pull_request_params
    params.permit(
      project: [:path_with_namespace],
      object_attributes: [
        :id,
        :iid,
        :target_branch,
        :source_branch,
        :state,
        :action,
        :title,
        :description,
        :url,
        :created_at,
        :updated_at,
        last_commit: [:id]
      ]
    )
  end
end
