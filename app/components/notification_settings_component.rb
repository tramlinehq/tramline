class NotificationSettingsComponent < ViewComponent::Base
  include ApplicationHelper

  InvalidNotificationSettings = Class.new(StandardError)

  NOTIFICATIONS = {
    release_scheduled: {icon: "clock.svg", description: "Your scheduled release will run in a few hours"},
    release_started: {icon: "zap.svg", description: "A new release was started for the release train"},
    backmerge_failed: {icon: "alert_circle.svg", description: "Tramline failed to create a backmerge PR for the commit in the release"},
    release_ended: {icon: "sparkles.svg", description: "The release finished successfully"},
    release_finalize_failed: {icon: "alert_circle.svg", description: "The release finalization failed"},
    release_stopped: {icon: "stop_circle.svg", description: "The release was stopped before it finished"},
    release_health_events: {icon: "heart_pulse.svg", description: "A health event has occurred for the release"},
    build_available_v2: {icon: "drill.svg", description: "A new build is available for a direct download"},
    internal_release_finished: {icon: "sparkles.svg", description: "The release finished successfully"},
    internal_release_failed: {icon: "alert_circle.svg", description: "The internal build step failed"},
    beta_release_failed: {icon: "alert_circle.svg", description: "The release candidate step failed"},
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
    workflow_run_unavailable: {icon: "alert_circle.svg", description: "A workflow run was not found"}
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

    attr_reader :setting
    delegate :id, :active?, :notification_channels, :notification_provider, to: :setting

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
      setting.kind == NotificationSetting.kinds[:build_available]
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

    def status_text
      return "Enabled" if setting.active?
      "Disabled"
    end

    def status_type
      return :success if setting.active?
      :neutral
    end

    def status_pill
      BadgeComponent.new(text: status_text, status: status_type)
    end

    def default_channels
      setting.notification_channels&.map(&:to_json).presence || @train.notification_channel.to_json
    end

    def channel_select_options
      options_for_select(display_channels(setting.channels) { |chan| "#" + chan[:name] }, default_channels)
    end
  end
end
