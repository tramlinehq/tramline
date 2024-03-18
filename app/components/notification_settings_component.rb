class NotificationSettingsComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  InvalidNotificationSettings = Class.new(StandardError)

  NOTIFICATIONS = {
    release_scheduled: {number: 1, icon: "v2/clock.svg", description: "Your scheduled release will run in a few hours"},
    release_started: {number: 2, icon: "v2/zap.svg", description: "A new release was started for the release train"},
    step_started: {number: 3, icon: "v2/play.svg", description: "A step was started for the release train"},
    step_failed: {number: 4, icon: "v2/alert_circle.svg", description: "A step failed to run fully for the release train"},
    backmerge_failed: {number: 5, icon: "v2/alert_circle.svg", description: "Tramline failed to create a backmerge PR for the commit in the release"},
    submit_for_review: {number: 6, icon: "v2/clipboard_list.svg", description: "A build was submitted for review to store for the release"},
    review_approved: {number: 7, icon: "v2/clipboard_check.svg", description: "A production build review was approved by the store"},
    review_failed: {number: 8, icon: "v2/alert_circle.svg", description: "A production build review was rejected by the store"},
    staged_rollout_updated: {number: 9, icon: "v2/arrow_big_up_dash.svg", description: "The staged rollout was increased for the production build in the store"},
    staged_rollout_paused: {number: 10, icon: "v2/pause.svg", description: "The staged rollout was paused for the production build in the store"},
    staged_rollout_resumed: {number: 11, icon: "v2/play.svg", description: "The staged rollout was resumed for the production build in the store"},
    staged_rollout_halted: {number: 12, icon: "v2/stop_circle.svg", description: "The staged rollout was halted for the production build in the store"},
    staged_rollout_completed: {number: 13, icon: "v2/sparkles.svg", description: "The staged rollout was completed for the production build in the store"},
    staged_rollout_fully_released: {number: 14, icon: "v2/fast_forward.svg", description: "The staged rollout was fully released to 100% for the production build in the store"},
    deployment_finished: {number: 15, icon: "v2/truck.svg", description: "The distribution was successful to a channel"},
    deployment_failed: {number: 16, icon: "v2/alert_circle.svg", description: "The distribution to a channel failed"},
    release_ended: {number: 17, icon: "v2/sparkles.svg", description: "The release finished successfully"},
    release_stopped: {number: 18, icon: "v2/stop_circle.svg", description: "The release was stopped before it finished"}
  }.with_indifferent_access

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

  def display_settings
    settings.sort_by { |setting| NOTIFICATIONS[setting.kind][:number] }
  end

  def description_for(setting)
    NOTIFICATIONS[setting.kind][:description]
  end

  def icon_for(setting)
    NOTIFICATIONS[setting.kind][:icon] || "aerial_lift.svg"
  end

  def enabled?
    train.send_notifications?
  end

  def status_text(setting)
    return "Enabled" if setting.active?
    "Disabled"
  end

  def status_type(setting)
    return :success if setting.active?
    :neutral
  end
end
