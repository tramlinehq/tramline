class TrainKickoffJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(train_id)
    train = Train.find(train_id)
    return unless train.active?

    response = Triggers::Release.call(train, automatic: true)

    if response.success?
      Rails.logger.info "A new release has started successfully for train – ", train
    else
      Rails.logger.info "A new release failed to start for train #{train.name} due to #{response.body}"
    end
  end
end
