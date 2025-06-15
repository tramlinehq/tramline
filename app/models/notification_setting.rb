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
  THREADED_CHANGELOG_NOTIFICATION_KINDS = [:rc_finished, :production_rollout_started]
  CHANGELOG_PER_MESSAGE_LIMIT = 2

  scope :active, -> { where(active: true) }
  scope :release_specific_channel_allowed, -> { where(kind: RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS) }
  scope :release_specific_channel_not_allowed, -> { where(kind: RELEASE_SPECIFIC_CHANNEL_NOT_ALLOWED_KINDS) }
  delegate :app, to: :train
  delegate :notification_provider, to: :app
  delegate :channels, to: :notification_provider
  before_validation :handle_active_flag
  validate :notification_channels_settings

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
    return unless kind.to_sym.in?(THREADED_CHANGELOG_NOTIFICATION_KINDS)

    case kind.to_sym
    when :rc_finished then notify_rc_finished!(message, params)
    when :production_rollout_started then notify_production_rollout_started!(message, params)
    else true
    end
  end

  def send_notifications?
    app.notifications_set_up? && active?
  end

  def release_specific_notifiable?
    train.notifications_release_specific_channel_enabled? && release_specific_channel_allowed?
  end

  def release_specific_channel_allowed?
    kind.to_sym.in?(RELEASE_SPECIFIC_CHANNEL_ALLOWED_KINDS)
  end

  private

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

  def notify_rc_finished!(message, params)
    notifiable_channels.each do |channel|
      thread_id =
        notification_provider.notify_with_threaded_changelog!(channel, message, kind, params,
          changelog_key: :diff_changelog,
          changelog_partitions: CHANGELOG_PER_MESSAGE_LIMIT,
          header_affix: "Changes in this build")

      # show full changelog when necessary
      # todo: we can probably also encapsulate this nicely like we do for notify_with_threaded_changelog!
      # todo: but in the interest of time, this is sort of manually hand-constructed
      show_full_changelog = !params[:first_pre_prod_release] || false
      if show_full_changelog
        full = params[:full_changelog]
        full_parts = full.in_groups_of(CHANGELOG_PER_MESSAGE_LIMIT, false)

        # first send the initial part of the changelog
        header_affix = "Full release changelog"
        notification_provider.notify_changelog!(channel["id"], message, thread_id, full_parts[0],
          header_affix: header_affix,
          continuation: false)

        # send the rest of the parts as "continuations"
        full_parts[1..].each.with_index(2) do |change_group, index|
          continuation_header_affix = "#{header_affix} (#{index}/#{full_parts.size})"
          notification_provider.notify_changelog!(channel["id"], message, thread_id, change_group,
            header_affix: continuation_header_affix,
            continuation: true)
        end
      end
    end
  end

  def notify_production_rollout_started!(message, params)
    notifiable_channels.each do |channel|
      notification_provider.notify_with_threaded_changelog!(channel, message, kind, params,
        changelog_key: :diff_changelog,
        changelog_partitions: CHANGELOG_PER_MESSAGE_LIMIT,
        header_affix: "Changes in release")
    end
  end
end
