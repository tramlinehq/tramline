module SiteAnalytics
  require "posthog"

  ANALYTICS = PostHog::Client.new(
    {
      api_key: ENV["POSTHOG_API_KEY"] || "",
      host: ENV["POSTHOG_HOST"] || "https://us.i.posthog.com",
      on_error: proc { |_status, msg| Rails.logger.debug { msg } },
      test_mode: !Rails.env.production?
    }
  )

  class << self
    def identify_and_group(user, organization)
      return if user.blank? || organization.blank?
      identify(user)
      group(user, organization)
    rescue => e
      elog(e)
    end

    def group(user, organization)
      return if user.blank? || organization.blank?

      ANALYTICS.group_identify(
        group_type: "organization",
        group_key: organization.id,
        properties: {
          name: organization.name
        }
      )
    rescue => e
      elog(e)
    end

    def identify(user)
      return if user.blank?

      ANALYTICS.capture(
        distinct_id: user.id,
        event: "user_identified",
        properties: {
          "$set" => {
            email: user.email,
            name: user.full_name
          }
        }
      )
    rescue => e
      elog(e)
    end

    def track(user, organization, device, event, properties = {})
      return if user.blank? || organization.blank?

      ANALYTICS.capture(
        distinct_id: user.id,
        event: event.titleize,
        properties: properties.merge(
          :browser => device&.name,
          "$groups" => {
            organization: organization.id
          }
        )
      )
    rescue => e
      elog(e)
    end

    private

    def elog(e)
      Rails.logger.debug { e }
      Sentry.capture_exception(e, level: :debug)
      nil
    end
  end
end
