module SiteAnalytics
  require "june/analytics"

  ANALYTICS = June::Analytics.new(
    {
      write_key: ENV["JUNE_ANALYTICS_KEY"] || "",
      on_error: proc { |_status, msg| Rails.logger.debug msg },
      stub: !Rails.env.production?
    }
  )

  def self.group_and_track(user, organization, device, event)
    ANALYTICS.group(
      user_id: user.id,
      group_id: organization.id,
      traits: {
        name: organization.name
      }
    )

    track(user, organization, device, event)
  end

  def self.identify_and_group(user, organization)
    identify(user)

    ANALYTICS.group(
      user_id: user.id,
      group_id: organization.id,
      traits: {
        name: organization.name
      }
    )
  end

  def self.identify(user)
    ANALYTICS.identify(
      user_id: user.id,
      traits: {
        email: user.email,
        name: user.full_name
      }
    )
  end

  def self.track(user, organization, device, event)
    ANALYTICS.track(
      user_id: user.id,
      event: event.titleize,
      properties: {
        browser: device.name
      },
      context: {
        groupId: organization.id
      }
    )
  end
end
