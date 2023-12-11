# == Schema Information
#
# Table name: notification_settings
#
#  id                    :uuid             not null, primary key
#  active                :boolean          default(TRUE), not null
#  kind                  :string           not null, indexed => [train_id]
#  notification_channels :jsonb
#  user_groups           :jsonb
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  train_id              :uuid             not null, indexed, indexed => [kind]
#
class NotificationSetting < ApplicationRecord
  has_paper_trail
  using RefinedHash
  include Displayable

  belongs_to :train

  enum kind: {
    deployment_finished: "deployment_finished",
    release_ended: "release_ended",
    release_stopped: "release_stopped",
    release_started: "release_started",
    step_started: "step_started",
    step_failed: "step_failed",
    submit_for_review: "submit_for_review",
    review_approved: "review_approved",
    review_failed: "review_failed",
    staged_rollout_updated: "staged_rollout_updated",
    release_scheduled: "release_scheduled",
    backmerge_failed: "backmerge_failed",
    staged_rollout_paused: "staged_rollout_paused",
    staged_rollout_resumed: "staged_rollout_resumed",
    staged_rollout_halted: "staged_rollout_halted",
    staged_rollout_fully_released: "staged_rollout_fully_released"
  }

  scope :active, -> { where(active: true) }
  delegate :app, to: :train
  delegate :notification_provider, to: :app
  delegate :channels, to: :notification_provider
  validate :notification_channels_settings

  def send_notifications?
    app.notifications_set_up? && active? && notification_channels.present?
  end

  def notify!(message, params)
    return unless send_notifications?
    notification_channels.each do |channel|
      notification_provider.notify!(channel["id"], message, kind, params)
    end
  end

  def notify_with_snippet!(message, params, snippet_content, snippet_title)
    return unless send_notifications?
    notification_channels.each do |channel|
      notification_provider.notify_with_snippet!(channel["id"], message, kind, params, snippet_content, snippet_title)
    end
  end

  def notification_channels_settings
    errors.add(:notification_channels, :at_least_one) if active? && notification_channels.blank?
  end

  def self.replicate(new_train)
    vals = all.map { _1.attributes.with_indifferent_access.except(:id).update_key(:train_id) { new_train.id } }
    NotificationSetting.upsert_all(vals, unique_by: [:train_id, :kind])
  end
end
