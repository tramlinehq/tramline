# == Schema Information
#
# Table name: notification_settings
#
#  id                       :uuid             not null, primary key
#  active                   :boolean          default(TRUE), not null
#  kind                     :string           not null, indexed => [train_id]
#  notification_channels    :jsonb
#  release_specific_channel :jsonb
#  release_specific_enabled :boolean          default(FALSE)
#  user_groups              :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  train_id                 :uuid             not null, indexed, indexed => [kind]
#
class NotificationSetting < ApplicationRecord
  has_paper_trail
  using RefinedHash
  include Displayable

  belongs_to :train

  enum :kind, {
    release_started: "release_started",
    release_stopped: "release_stopped",
    release_finalize_failed: "release_finalize_failed",
    release_ended: "release_ended",
    release_scheduled: "release_scheduled",
    release_health_events: "release_health_events",
    backmerge_failed: "backmerge_failed",
    build_available_v2: "build_available_v2",
    internal_release_finished: "internal_release_finished",
    internal_release_failed: "internal_release_failed",
    beta_release_failed: "beta_release_failed",
    beta_submission_finished: "beta_submission_finished",
    internal_submission_finished: "internal_submission_finished",
    submission_failed: "submission_failed",
    production_submission_started: "production_submission_started",
    production_submission_in_review: "production_submission_in_review",
    production_submission_approved: "production_submission_approved",
    production_submission_rejected: "production_submission_rejected",
    production_submission_cancelled: "production_submission_cancelled",
    production_rollout_started: "production_rollout_started",
    production_rollout_paused: "production_rollout_paused",
    production_rollout_resumed: "production_rollout_resumed",
    production_rollout_halted: "production_rollout_halted",
    production_rollout_updated: "production_rollout_updated",
    production_release_finished: "production_release_finished",
    workflow_run_failed: "workflow_run_failed",
    workflow_run_halted: "workflow_run_halted",
    workflow_run_unavailable: "workflow_run_unavailable",
    workflow_trigger_failed: "workflow_trigger_failed"
  }

  RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS = [
    :release_started,
    :release_scheduled
  ]

  RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS = NotificationSetting.kinds.keys.map(&:to_sym) - RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS

  scope :active, -> { where(active: true) }
  scope :release_specific_channel_allowed, -> { where(kind: RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS) }
  scope :release_specific_channel_not_allowed, -> { where(kind: RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS) }
  delegate :app, to: :train
  delegate :notification_provider, to: :app
  delegate :channels, to: :notification_provider
  validate :notification_channels_settings

  def notify!(message, params, file_id = nil, file_title = nil)
    notifiable_channels.each do |channel|
      notification_provider.notify!(channel["id"], message, kind, params, file_id, file_title)
    end
  end

  def notify_with_snippet!(message, params, snippet_content, snippet_title)
    notifiable_channels.each do |channel|
      notification_provider.notify_with_snippet!(channel["id"], message, kind, params, snippet_content, snippet_title)
    end
  end

  def notifiable_channels
    return unless app.notifications_set_up?

    channels = []

    if active? && notification_channels.present?
      channels.concat(notification_channels)
    end

    if release_specific_enabled? && release_specific_channel.present?
      channels.append(release_specific_channel)
    end

    channels.compact.uniq { |c| c["id"] }
  end

  def release_specific_channel_allowed?
    !kind.to_sym.in?(RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS)
  end

  def notification_channels_settings
    if active? && notification_channels.blank?
      errors.add(:notification_channels, :at_least_one)
    end

    if release_specific_enabled?
      if !release_specific_channel_allowed?
        errors.add(:release_specific_enabled, :release_specific_channel_not_allowed_for_this_kind)
      elsif !train.notifications_release_specific_channel_enabled?
        errors.add(:release_specific_enabled, :release_specific_not_enabled_in_train)
      end
    end
  end

  # rubocop:disable Rails/SkipsModelValidations
  def self.replicate(new_train)
    vals = all.map { _1.attributes.with_indifferent_access.except(:id).update_key(:train_id) { new_train.id } }
    NotificationSetting.upsert_all(vals, unique_by: [:train_id, :kind])
  end
  # rubocop:enable Rails/SkipsModelValidations
end
