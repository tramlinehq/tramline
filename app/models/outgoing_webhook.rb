# == Schema Information
#
# Table name: outgoing_webhooks
#
#  id          :uuid             not null, primary key
#  active      :boolean          default(TRUE), indexed
#  description :text
#  event_types :text             default(NULL), is an Array
#  url         :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  train_id    :uuid             not null, indexed
#
class OutgoingWebhook < ApplicationRecord
  has_paper_trail

  belongs_to :train

  validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}
  validates :event_types, presence: true

  # Remove enum and work with plain array validation
  VALID_EVENT_TYPES = %w[
    release_started
    release_finished
    release_stopped
    build_available
    internal_release_finished
    beta_release_finished
    production_release_complete
    workflow_run_finished
    submission_started
    rollout_started
    rollout_completed
  ].freeze

  validate :event_types_are_valid

  private

  def event_types_are_valid
    return if event_types.blank?

    invalid_types = event_types - VALID_EVENT_TYPES
    errors.add(:event_types, "contains invalid event types: #{invalid_types.join(", ")}") if invalid_types.any?
  end

  scope :active, -> { where(active: true) }
  scope :for_event_type, ->(event_type) { where("? = ANY(event_types)", event_type) }
end
