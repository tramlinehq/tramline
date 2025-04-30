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

    channel_name =
      if app.cross_platform?
        "release-#{app.name}-#{release.release_version}"
      else
        "release-#{app.name}-#{app.platform}-#{release.release_version}"
      end

    # Slack validation accepts only
    # letters (lower case), numbers, hyphens and underscores
    sanitized_channel_name = channel_name.downcase.gsub(/\W/, "-")
    notification_channel = notification_provider.create_channel!(sanitized_channel_name)

    release.set_notification_channel!(notification_channel)
    notification_settings.release_specific_channel_allowed.update(notification_channels: [notification_channel])
  end
end
