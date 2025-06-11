# == Schema Information
#
# Table name: notification_settings
#
#  id                       :uuid             not null, primary key
#  active                   :boolean          default(TRUE), not null
#  core_enabled             :boolean          default(FALSE), not null
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
    rc_finished: "rc_finished",
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
  SLACK_CHANGELOG_THREAD_NOTIFICATION_KINDS = [:rc_finished]
  CHANGELOG_PER_MESSAGE_LIMIT = 20

  scope :active, -> { where(active: true) }
  scope :release_specific_channel_allowed, -> { where(kind: RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS) }
  scope :release_specific_channel_not_allowed, -> { where(kind: RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS) }
  delegate :app, to: :train
  delegate :notification_provider, to: :app
  delegate :channels, to: :notification_provider
  before_validation :handle_active_flag
  validate :notification_channels_settings

  def handle_active_flag
    if release_specific_notifiable?
      unless active?
        self.core_enabled = false
        self.release_specific_enabled = false
      end
    else
      unless core_enabled?
        self.active = false
      end
    end
  end

  def notify!(message, params, file_id = nil, file_title = nil)
    return unless send_notifications?

    notifiable_channels.each do |channel|
      notification_provider.notify!(channel["id"], message, kind, params, file_id, file_title)
    end
  end

  def notify_with_snippet!(message, params, snippet_content, snippet_title)
    return unless send_notifications?

    notifiable_channels.each do |channel|
      notification_provider.notify_with_snippet!(channel["id"], message, kind, params, snippet_content, snippet_title)
    end
  end

  def notify_with_changelog!(message, params)
    return unless send_notifications?
    return unless rc_finished?

    notifiable_channels.each do |channel|
      if rc_finished?
        changes_since_last_run = params[:changes_since_last_run]
        last_run_change_groups = changes_since_last_run.in_groups_of(CHANGELOG_PER_MESSAGE_LIMIT, false)
        last_run_part_count = last_run_change_groups.size

        changes_since_last_release = params[:changes_since_last_release]
        last_release_change_groups = changes_since_last_release.in_groups_of(CHANGELOG_PER_MESSAGE_LIMIT, false)
        last_release_part_count = last_release_change_groups.size

        params[:changelog] = {
          last_run: last_run_change_groups[0],
          last_run_part_count:,
          last_release: last_release_change_groups[0],
          last_release_part_count:
        }

        ####### Changes since last run (dual-set) #######
        # Send the main message notification
        # This will contain either RC changelog, or the full changelog depending on what is available
        thread_id = notification_provider.notify!(channel["id"], message, kind, params)

        if last_run_part_count > 1
          last_run_change_groups[1..].each.with_index(2) do |change_group, index|
            header = "Changelog part #{index}/#{last_run_part_count}"
            notification_provider.notify_changelog_in_thread!(channel["id"], message, thread_id, change_group, header:)
          end
        end

        ####### Changes since last release (dual-set) #######
        if last_run_part_count > 0
          # The notification template shows the full release changelog part 1 if last_run_part_count is 0
          # So header is needed only when the full changelog is posted in thread
          header = "Changes since last release (part 1/#{last_release_part_count})"
          notification_provider.notify_changelog_in_thread!(channel["id"], message, thread_id, last_release_change_groups[0], header:)
        end

        if last_release_part_count > 1
          last_release_change_groups[1..].each.with_index(2) do |change_group, index|
            header = "Changes since last release part #{index}/#{last_release_part_count}"
            notification_provider.notify_changelog_in_thread!(channel["id"], message, thread_id, change_group, header:)
          end
        end
      end
    end
  end

  def send_notifications?
    app.notifications_set_up? && active?
  end

  def notifiable_channels
    channels = []

    if core_enabled? && notification_channels.present?
      channels.concat(notification_channels)
    end

    if release_specific_notifiable? && release_specific_enabled? && release_specific_channel.present?
      channels.append(release_specific_channel)
    end

    channels.compact.uniq { |c| c["id"] }
  end

  def release_specific_notifiable?
    train.notifications_release_specific_channel_enabled? && release_specific_channel_allowed?
  end

  def release_specific_channel_allowed?
    kind.to_sym.in?(RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS)
  end

  def notification_channels_settings
    if core_enabled? && notification_channels.blank?
      errors.add(:notification_channels, :at_least_one)
    end

    if release_specific_enabled?
      if !release_specific_channel_allowed?
        errors.add(:release_specific_enabled, :release_specific_channel_not_allowed_for_this_kind)
      elsif !train.notifications_release_specific_channel_enabled?
        errors.add(:release_specific_enabled, :release_specific_not_enabled_in_train)
      end
    end

    if active? && ![core_enabled, release_specific_enabled].any?
      errors.add(:active, :at_least_one)
    end
  end

  # rubocop:disable Rails/SkipsModelValidations
  def self.replicate(new_train)
    vals = all.map { _1.attributes.with_indifferent_access.except(:id).update_key(:train_id) { new_train.id } }
    NotificationSetting.upsert_all(vals, unique_by: [:train_id, :kind])
  end

  # rubocop:enable Rails/SkipsModelValidations
end
