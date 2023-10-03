class NotificationSettingsComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper
  attr_reader :notification_settings, :train

  delegate :writer?, to: :helpers

  InvalidNotificationSettings = Class.new(StandardError)

  NOTIFICATIONS = {
    release_scheduled: {number: 1, description: "Your scheduled release will run in a few hours."},
    release_started: {number: 2, description: "A new release was started for the release train."},
    step_started: {number: 3, description: "A step was started for the release train."},
    step_failed: {number: 4, description: "A step failed to run fully for the release train."},
    backmerge_failed: {number: 5, description: "Tramline failed to create a backmerge PR for the commit in the release."},
    submit_for_review: {number: 6, description: "A build was submitted for review to store for the release."},
    review_approved: {number: 7, description: "A production build review was approved by the store."},
    staged_rollout_updated: {number: 8, description: "The staged rollout was increased for the production build in the store."},
    staged_rollout_paused: {number: 9, description: "The staged rollout was paused for the production build in the store."},
    staged_rollout_resumed: {number: 10, description: "The staged rollout was resumed for the production build in the store."},
    staged_rollout_halted: {number: 11, description: "The staged rollout was halted for the production build in the store."},
    staged_rollout_fully_released: {number: 12, description: "The staged rollout was fully released to 100% for the production build in the store."},
    deployment_finished: {number: 13, description: "The distribution was successful to a channel."},
    release_ended: {number: 14, description: "The release finished successfully."},
    release_stopped: {number: 15, description: "The release was stopped before it finished."}
  }.with_indifferent_access

  unless Set.new(NOTIFICATIONS.keys).eql?(Set.new(NotificationSetting.kinds.keys))
    raise InvalidNotificationSettings
  end

  def initialize(notification_settings:, train:)
    @train = train
    @notification_settings = notification_settings
  end

  def ordered_notification_settings
    notification_settings.sort_by { |setting| NOTIFICATIONS[setting.kind][:number] }
  end

  def editable?
    train.active_runs.none?
  end

  def description_for(setting)
    NOTIFICATIONS[setting.kind][:description]
  end
end
