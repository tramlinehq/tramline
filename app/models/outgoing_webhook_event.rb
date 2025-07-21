# == Schema Information
#
# Table name: outgoing_webhook_events
#
#  id                  :uuid             not null, primary key
#  error_message       :text
#  event_timestamp     :datetime         not null, indexed => [outgoing_webhook_id], indexed, indexed => [train_id]
#  response_data       :text
#  status              :string           not null, indexed
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  outgoing_webhook_id :uuid             not null, indexed => [event_timestamp], indexed
#  train_id            :uuid             not null, indexed, indexed => [event_timestamp]
#
class OutgoingWebhookEvent < ApplicationRecord
  has_paper_trail

  belongs_to :train
  belongs_to :outgoing_webhook

  enum :status, {pending: "pending", success: "success", failed: "failed"}

  validates :event_timestamp, presence: true
  validates :status, presence: true

  scope :recent, -> { order(event_timestamp: :desc) }
  scope :for_webhook, ->(webhook) { where(outgoing_webhook: webhook) }
  scope :for_train, ->(train) { where(train: train) }

  def successful?
    success?
  end

  def failed?
    status == "failed"
  end
end
