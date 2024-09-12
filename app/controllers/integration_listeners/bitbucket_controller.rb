class IntegrationListeners::BitbucketController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  def providable_params
    super.merge(code: code)
  end

  # TODO: what do we want to do when these events come in
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

  def handle_ping
  end

  def handle_push
    result = Action.process_push_webhook(train, push_params)
    response = result.ok? ? result.value! : Response.new(:unprocessable_entity, "Error processing push, error: #{result.error}")

    Rails.logger.debug response.body
    head response.status
  end

  def handle_pull_request
    result = Action.process_pull_request_webhook(train, pull_request_params)
    response = result.ok? ? result.value! : Response.new(:unprocessable_entity, "Error processing pull request")

    Rails.logger.debug response.body
    head response.status
  end

  def event_type
    request.headers["X-Event-Key"]
  end

  def train
    @train ||= Train.find(params[:train_id])
  end

  def pull_request_params
    params.permit(
      repository: [:name, :full_name],
      pullrequest: [
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
