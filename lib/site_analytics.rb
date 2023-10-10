module SiteAnalytics
  extend Loggable
  require "june/analytics"

  ANALYTICS = June::Analytics.new(
    {
      write_key: ENV["JUNE_ANALYTICS_KEY"] || "",
      on_error: proc { |_status, msg| Rails.logger.debug msg },
      stub: !Rails.env.production?
    }
  )

  def self.identify_and_group(user, organization)
    return if user.blank? || organization.blank?
    identify(user)
    group(user, organization)
  rescue
    elog(e)
  end

  def self.group(user, organization)
    return if user.blank? || organization.blank?
    ANALYTICS.group(
      user_id: user.id,
      group_id: organization.id,
      traits: {
        name: organization.name
      }
    )
  rescue
    elog(e)
  end

  def self.identify(user)
    return if user.blank?
    ANALYTICS.identify(
      user_id: user.id,
      traits: {
        email: user.email,
        name: user.full_name
      }
    )
  rescue
    elog(e)
  end

  def self.track(user, organization, device, event)
    return if user.blank? || organization.blank?
    ANALYTICS.track(
      user_id: user.id,
      event: event.titleize,
      properties: {
        browser: device&.name
      },
      context: {
        groupId: organization.id
      }
    )
  rescue
    elog(e)
  end
end
