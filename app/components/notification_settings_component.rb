class NotificationSettingsComponent < ViewComponent::Base
  include ApplicationHelper

  InvalidNotificationSettings = Class.new(StandardError)

  STATUS_PILL_ENABLED = BadgeComponent.new(text: "Enabled", status: :success)
  STATUS_PILL_DISABLED = BadgeComponent.new(text: "Disabled", status: :failure)
  STATUS_PILL_NEUTRAL = BadgeComponent.new(text: "Not Applicable", status: :neutral)

  NOTIFICATIONS = {
    release_scheduled: {icon: "clock.svg", description: "Your scheduled release will run in a few hours"},
    release_started: {icon: "zap.svg", description: "A new release was started for the release train"},
    backmerge_failed: {icon: "alert_circle.svg", description: "Tramline failed to create a backmerge PR for the commit in the release"},
    release_ended: {icon: "sparkles.svg", description: "The release finished successfully"},
    release_finalize_failed: {icon: "alert_circle.svg", description: "The release finalization failed"},
    release_stopped: {icon: "stop_circle.svg", description: "The release was stopped before it finished"},
    release_health_events: {icon: "heart_pulse.svg", description: "A health event has occurred for the release"},
    build_available_v2: {icon: "drill.svg", description: "A new build is available for download"},
    internal_release_finished: {icon: "sparkles.svg", description: "The internal release finished successfully"},
    internal_release_failed: {icon: "alert_circle.svg", description: "The internal build step failed"},
    beta_release_failed: {icon: "alert_circle.svg", description: "The release candidate step failed"},
    rc_finished: {icon: "sparkles.svg", description: "The RC release finished"},
    soak_period_started: {icon: "alarm_clock.svg", description: "The release entered the soak period"},
    soak_period_ended: {icon: "alarm_clock.svg", description: "The release soak period ended"},
    soak_period_extended: {icon: "alarm_clock.svg", description: "The release soak period was extended"},
    beta_submission_finished: {icon: "sparkles.svg", description: "The beta submission finished successfully"},
    internal_submission_finished: {icon: "sparkles.svg", description: "The internal submission finished successfully"},
    submission_failed: {icon: "alert_circle.svg", description: "The submission failed"},
    production_submission_started: {icon: "play.svg", description: "A production submission started"},
    production_submission_in_review: {icon: "clipboard_list.svg", description: "A production submission is in review"},
    production_submission_approved: {icon: "clipboard_check.svg", description: "A production submission was approved by the store"},
    production_submission_rejected: {icon: "alert_circle.svg", description: "A production submission was rejected by the store"},
    production_submission_cancelled: {icon: "alert_circle.svg", description: "A production submission was cancelled"},
    production_rollout_started: {icon: "play.svg", description: "A production rollout started"},
    production_rollout_paused: {icon: "pause.svg", description: "A production rollout was paused"},
    production_rollout_resumed: {icon: "play.svg", description: "A production rollout was resumed"},
    production_rollout_halted: {icon: "stop_circle.svg", description: "A production rollout was halted"},
    production_rollout_updated: {icon: "arrow_big_up_dash.svg", description: "A production rollout was updated"},
    production_release_finished: {icon: "sparkles.svg", description: "A production release finished"},
    workflow_run_failed: {icon: "alert_circle.svg", description: "A workflow run failed"},
    workflow_run_halted: {icon: "stop_circle.svg", description: "A workflow run was halted"},
    workflow_run_unavailable: {icon: "alert_circle.svg", description: "A workflow run was not found"},
    workflow_trigger_failed: {icon: "stop_circle.svg", description: "A workflow trigger failed"}
  }.map
    .with_index { |(key, value), index| [key, value.merge(number: index.succ)] }
    .to_h
    .with_indifferent_access

  unless Set.new(NOTIFICATIONS.keys).eql?(Set.new(NotificationSetting.kinds.keys))
    raise InvalidNotificationSettings
  end

  def initialize(settings:, train:)
    @train = train
    @settings = settings
  end

  attr_reader :settings, :train
  delegate :writer?, to: :helpers
  delegate :app, to: :train

  def notification_setting_component(setting)
    NotificationSettingComponent.new(app, train, setting)
  end

  def header_columns
    if @train.notifications_release_specific_channel_enabled?
      ["kind", "core channels", "release specific channel"]
    else
      %w[kind channels status]
    end
  end

  def display_settings
    settings.sort_by { |setting| NOTIFICATIONS[setting.kind][:number] }
  end

  def enabled?
    train.send_notifications?
  end

  # this is a non view-component, just used for managing view state
  class NotificationSettingComponent
    include ApplicationHelper
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::FormOptionsHelper

    def initialize(app, train, setting)
      @app = app
      @train = train
      @setting = setting
    end

    attr_reader :setting, :app
    delegate :id, :active?, :notification_channels, :notification_provider, :channels, to: :setting

    def edit_path
      edit_app_train_notification_setting_path(@app, @train, setting)
    end

    def edit_form_params
      {
        model: [@app, @train, setting],
        url: app_train_notification_setting_path(@app, @train, setting),
        method: :put
      }
    end

    def needs_invite?
      setting.kind == NotificationSetting.kinds[:build_available_v2]
    end

    def edit_frame_id
      "#{setting.kind}_config"
    end

    def display
      setting.display_attr(:kind)
    end

    def description
      NOTIFICATIONS[setting.kind][:description]
    end

    def modal_title
      "Notification: #{display}"
    end

    def icon
      NOTIFICATIONS[setting.kind][:icon] || "aerial_lift.svg"
    end

    def status_pill
      if setting.active? && setting.core_enabled?
        return STATUS_PILL_ENABLED
      end

      STATUS_PILL_DISABLED
    end

    def release_specific_status_pill
      return STATUS_PILL_NEUTRAL unless release_specific_channel_allowed?

      if setting.active? && setting.release_specific_enabled?
        return STATUS_PILL_ENABLED
      end

      STATUS_PILL_DISABLED
    end

    def default_channels
      setting.notification_channels&.map(&:to_json).presence || @train.notification_channel.to_json
    end

    def channel_select_options
      options_for_select(display_channels(setting.channels) { |chan| "#" + chan[:name] }, default_channels)
    end

    def core_prefix_text
      release_specific_channel_allowed? ? "Core " : ""
    end

    def release_specific_channel_allowed?
      setting.release_specific_channel_allowed? && @train.notifications_release_specific_channel_enabled?
    end
  end
end
