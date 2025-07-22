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

  # Event types with their JSON schemas for validation
  VALID_EVENT_TYPES = {
    "release.started" => {
      "type" => "object",
      "required" => [
        "full_changelog",
        "release_version",
        "release_branch_name",
        "platform"
      ],
      "properties" => {
        "full_changelog" => {
          "type" => "array"
        },
        "release_version" => {
          "type" => "string"
        },
        "release_branch_name" => {
          "type" => "string"
        },
        "platform" => {
          "type" => "string",
          "enum" => ["android", "ios"]
        }
      },
      "additionalProperties" => true
    },
    "release.ended" => {
      "type" => "object",
      "required" => [
        "full_changelog",
        "diff_changelog",
        "release_version",
        "release_branch_name",
        "platform"
      ],
      "properties" => {
        "full_changelog" => {
          "type" => "array"
        },
        "diff_changelog" => {
          "type" => "array"
        },
        "release_version" => {
          "type" => "string"
        },
        "release_branch_name" => {
          "type" => "string"
        },
        "platform" => {
          "type" => "string",
          "enum" => ["android", "ios"]
        }
      },
      "additionalProperties" => true
    },
    "rc.finished" => {
      "type" => "object",
      "required" => [
        "full_changelog",
        "diff_changelog",
        "release_version",
        "build_number",
        "release_branch_name",
        "platform"
      ],
      "properties" => {
        "full_changelog" => {
          "type" => "array"
        },
        "diff_changelog" => {
          "type" => "array"
        },
        "release_version" => {
          "type" => "string"
        },
        "build_number" => {
          "type" => "string"
        },
        "release_branch_name" => {
          "type" => "string"
        },
        "platform" => {
          "type" => "string",
          "enum" => ["android", "ios"]
        }
      },
      "additionalProperties" => true
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
