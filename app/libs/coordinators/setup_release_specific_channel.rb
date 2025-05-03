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

    notification_channel = nil

    5.times do |attempt|
      notification_channel = notification_provider.create_channel!(channel_name(attempt))
      break
    rescue Installations::Error => e
      # We will try in loop only if name_taken is the error, not in other cases
      break unless e.reason == "name_taken"
    end

    # Use the default notification channel if we did not receive a new channel
    release.set_notification_channel!(notification_channel.presence || train.notification_channel)
    notification_settings.release_specific_channel_allowed.update(notification_channels: [notification_channel])
  end

  def channel_name(attempt)
    name = "release-#{app.name}"
    name << "-#{app.platform}" unless app.cross_platform?
    name << "-#{release.release_version}"
    name << "-#{attempt}" if attempt > 0

    # Slack validation accepts only
    # letters (lower case), numbers, hyphens and underscores
    name.downcase.gsub(/\W/, "-")
  end
end
