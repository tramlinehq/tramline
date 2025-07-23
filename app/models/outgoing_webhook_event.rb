# == Schema Information
#
# Table name: outgoing_webhook_events
#
#  id              :bigint           not null, primary key
#  error_message   :text
#  event_payload   :jsonb            not null
#  event_timestamp :datetime         not null, indexed
#  event_type      :string           not null, indexed
#  response_data   :jsonb
#  status          :string           not null, indexed
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  release_id      :uuid             not null, indexed
#
class OutgoingWebhookEvent < ApplicationRecord
  has_paper_trail

  belongs_to :release

  VALID_EVENT_TYPES = {
    "rc.finished" => {schema: JSON.parse(Rails.root.join("config/schema/webhook_rc_finished.json").read)},
    "release.ended" => {schema: JSON.parse(Rails.root.join("config/schema/webhook_release_ended.json").read)},
    "release.started" => {schema: JSON.parse(Rails.root.join("config/schema/webhook_release_started.json").read)}
  }.freeze
  enum :status, {pending: "pending", success: "success", failed: "failed"}

  validate :event_type_is_valid
  validates :status, presence: true
  validates :event_type, presence: true
  validates :event_timestamp, presence: true

  scope :recent, -> { order(event_timestamp: :desc) }

  def record_failure!(error)
    update!(status: :failed, error_message: error)
  end

  def record_success!(response)
    update!(status: :success, response_data: response.to_json)
  end

  private

  def event_type_is_valid
    if VALID_EVENT_TYPES.exclude? event_type
      errors.add(:event_type, "contains invalid event type: #{event_type}")
    end
  end
end
