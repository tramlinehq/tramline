class NotificationSettingsComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  InvalidNotificationSettings = Class.new(StandardError)

  NOTIFICATIONS = {
    release_scheduled: { icon: "v2/clock.svg", description: "Your scheduled release will run in a few hours" },
    release_started: { icon: "v2/zap.svg", description: "A new release was started for the release train" },
    step_started: { icon: "v2/play.svg", description: "A step was started for the release train" },
    build_available: { icon: "v2/drill.svg", description: "A new build is available for a direct download" },
    step_failed: { icon: "v2/alert_circle.svg", description: "A step failed to run fully for the release train" },
    backmerge_failed: { icon: "v2/alert_circle.svg", description: "Tramline failed to create a backmerge PR for the commit in the release" },
    submit_for_review: { icon: "v2/clipboard_list.svg", description: "A build was submitted for review to store for the release" },
    review_approved: { icon: "v2/clipboard_check.svg", description: "A production build review was approved by the store" },
    review_failed: { icon: "v2/alert_circle.svg", description: "A production build review was rejected by the store" },
    staged_rollout_updated: { icon: "v2/arrow_big_up_dash.svg", description: "The staged rollout was increased for the production build in the store" },
    staged_rollout_paused: { icon: "v2/pause.svg", description: "The staged rollout was paused for the production build in the store" },
    staged_rollout_resumed: { icon: "v2/play.svg", description: "The staged rollout was resumed for the production build in the store" },
    staged_rollout_halted: { icon: "v2/stop_circle.svg", description: "The staged rollout was halted for the production build in the store" },
    staged_rollout_completed: { icon: "v2/sparkles.svg", description: "The staged rollout was completed for the production build in the store" },
    staged_rollout_fully_released: { icon: "v2/fast_forward.svg", description: "The staged rollout was fully released to 100% for the production build in the store" },
    deployment_finished: { icon: "v2/truck.svg", description: "The distribution was successful to a channel" },
    deployment_failed: { icon: "v2/alert_circle.svg", description: "The distribution to a channel failed" },
    release_ended: { icon: "v2/sparkles.svg", description: "The release finished successfully" },
    release_stopped: { icon: "v2/stop_circle.svg", description: "The release was stopped before it finished" }
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
      V2::StatusIndicatorPillComponent.new(text: status_text, status: status_type)
    end

    def default_channels
      setting.notification_channels&.map(&:to_json).presence || @train.notification_channel.to_json
    end

    def channel_select_options
      options_for_select(display_channels(setting.channels) { |chan| "#" + chan[:name] }, default_channels)
    end
  end
end
