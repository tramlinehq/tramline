# == Schema Information
#
# Table name: outgoing_webhooks
#
#  id               :uuid             not null, primary key
#  active           :boolean          default(TRUE), indexed
#  description      :text
#  event_types      :text             default([]), is an Array
#  url              :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  svix_endpoint_id :string
#  train_id         :uuid             not null, indexed
#
class OutgoingWebhook < ApplicationRecord
  has_paper_trail

  belongs_to :train
  has_many :outgoing_webhook_events, dependent: :destroy

  validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}
  validates :event_types, presence: true

  # Event types with their metadata and JSON schemas for validation
  VALID_EVENT_TYPES = {
    "release.started" => {
      name: "Release Started",
      schema: -> { JSON.parse(Rails.root.join("config/schema/webhook_release_started.json").read) }
    },
    "release.ended" => {
      name: "Release Ended",
      schema: -> { JSON.parse(Rails.root.join("config/schema/webhook_release_ended.json").read) }
    },
    "rc.finished" => {
      name: "Release Candidate Finished",
      schema: -> { JSON.parse(Rails.root.join("config/schema/webhook_rc_finished.json").read) }
    }
  }.freeze

  validate :event_types_are_valid

  private

  def event_types_are_valid
    return if event_types.blank?

    invalid_types = event_types - VALID_EVENT_TYPES.keys
    errors.add(:event_types, "contains invalid event types: #{invalid_types.join(", ")}") if invalid_types.any?
  end

  scope :active, -> { where(active: true) }
  scope :for_event_type, ->(event_type) { where("? = ANY(event_types)", event_type) }
end
