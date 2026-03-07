class IntegrationListeners::BitbucketController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]
  skip_before_action :require_organization!, only: [:events]

  def providable_params
    super.merge(code: code)
  end

  def events
    case event_type
    when "repo:push"
      handle_push
    when "pullrequest:created", "pullrequest:fulfilled", "pullrequest:rejected", "pullrequest:updated"
      handle_pull_request
    else
      head :ok
    end
  end

  private

  def handle_push
    Webhooks::ProcessPushWebhookJob.perform_async(params[:train_id], push_params.to_h)
    head :accepted
  end

  def handle_pull_request
    Webhooks::ProcessPullRequestWebhookJob.perform_async(params[:train_id], pull_request_params.to_h)
    head :accepted
  end

  def event_type
    request.headers["X-Event-Key"]
  end

  def pull_request_params
    params.permit(
      repository: [:name, :full_name],
      pullrequest: [
        :merge_commit,
        :id,
        :title,
        :description,
        :state,
        :created_on,
        :updated_on,
        links: [html: [:href]],
        destination: [branch: [:name], commit: [:hash]],
        source: [branch: [:name], commit: [:hash]]
      ]
    )
  end

  def push_params
    params.permit(
      push: [
        changes:
          [
            :created,
            :forced,
            :closed,
            new: [
              :name,
              :type,
              :merge_strategies, # NOTE: these two can be used for later merges
              :default_merge_strategy,
              target: [
                :type,
                :hash,
                :date,
                :message,
                parents: [
                  :hash,
                  :type,
                  links: [html: [:href]]
                ],
                author: [:type, :raw],
                links: [html: [:href]]
              ],
              links: [html: [:href]]
            ],
            commits: [
              :type,
              :hash,
              :date,
              :message,
              author: [:type, :raw],
              links: [html: [:href]],
              parents: [
                :hash,
                :type,
                links: [html: [:href]]
              ]
            ]
          ]
      ],
      repository: [:name, :full_name]
    )
  end
end
