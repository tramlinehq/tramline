class Coordinators::SetupReleaseSpecificChannel
  def self.call(release)
    new(release).call
  end

  attr_reader :release

  delegate :train, to: :release
  delegate :app, :notification_settings, to: :train
  delegate :notification_provider, to: :app

  def initialize(release)
    @release = release
  end

  def call
    return unless train.notifications_release_specific_channel_enabled?
    # Use the default notification channel if we did not receive a new channel
    notification_channel = notification_provider.create_channel!(channel_name) || train.notification_channel
    release.set_notification_channel!(notification_channel)
    notification_settings.release_specific_channel_allowed.update(notification_channels: [notification_channel])
  end

  def channel_name
    name = "release-#{app.name}"
    name << "-#{app.platform}" unless app.cross_platform?
    name << "-#{release.release_version}"
    # Slack validation accepts only
    # letters (lower case), numbers, hyphens and underscores
    name.downcase.gsub(/\W/, "-")
  end
end
