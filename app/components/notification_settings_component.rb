class NotificationSettingsComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper
  attr_reader :notification_settings, :train

  delegate :writer?, to: :helpers

  InvalidNotificationSettings = Class.new(StandardError)

  NOTIFICATIONS = {
    release_scheduled: {number: 1, icon: "clock.svg", description: "Your scheduled release will run in a few hours."},
    release_started: {number: 2, icon: "bolt.svg", description: "A new release was started for the release train."},
    step_started: {number: 3, icon: "paper_airplane.svg", description: "A step was started for the release train."},
    step_failed: {number: 4, icon: "failure.svg", description: "A step failed to run fully for the release train."},
    backmerge_failed: {number: 5, icon: "band_aid.svg", description: "Tramline failed to create a backmerge PR for the commit in the release."},
    submit_for_review: {number: 6, icon: "clipboard_copy.svg", description: "A build was submitted for review to store for the release."},
    review_approved: {number: 7, icon: "clipboard_check.svg", description: "A production build review was approved by the store."},
    review_failed: {number: 8, icon: "failure.svg", description: "A production build review was rejected by the store."},
    staged_rollout_updated: {number: 9, icon: "chart.svg", description: "The staged rollout was increased for the production build in the store."},
    staged_rollout_paused: {number: 10, icon: "pause.svg", description: "The staged rollout was paused for the production build in the store."},
    staged_rollout_resumed: {number: 11, icon: "play.svg", description: "The staged rollout was resumed for the production build in the store."},
    staged_rollout_halted: {number: 12, icon: "halt.svg", description: "The staged rollout was halted for the production build in the store."},
    staged_rollout_fully_released: {number: 13, icon: "fast_forward.svg", description: "The staged rollout was fully released to 100% for the production build in the store."},
    deployment_finished: {number: 14, icon: "truck_delivery.svg", description: "The distribution was successful to a channel."},
    deployment_failed: {number: 15, icon: "failure.svg", description: "The distribution to a channel failed."},
    release_ended: {number: 16, icon: "sparkles.svg", description: "The release finished successfully."},
    release_stopped: {number: 17, icon: "close_icon.svg", description: "The release was stopped before it finished."}
  }.with_indifferent_access

  unless Set.new(NOTIFICATIONS.keys).eql?(Set.new(NotificationSetting.kinds.keys))
    raise InvalidNotificationSettings
  end

  def initialize(notification_settings:, train:)
    @train = train
    @notification_settings = notification_settings
  end

  def settings
    notification_settings.sort_by { |setting| NOTIFICATIONS[setting.kind][:number] }
  end

  def description_for(setting)
    NOTIFICATIONS[setting.kind][:description]
  end

  def icon_for(setting)
    NOTIFICATIONS[setting.kind][:icon] || "aerial_lift.svg"
  end
end
