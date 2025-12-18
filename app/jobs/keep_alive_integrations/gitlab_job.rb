module KeepAliveIntegrations
  class GitlabJob < ApplicationJob
    queue_as :default

    def perform(gitlab_integration_id)
      gitlab_integration = GitlabIntegration.find_by(id: gitlab_integration_id)
      return unless gitlab_integration

      integration = gitlab_integration.integration
      return unless integration.connected? || integration.needs_reauth?

      if integration.needs_reauth?
        # Re-enqueue with a shorter interval to check again later
        re_enqueue(gitlab_integration_id, 3.hours)
        return
      end

      # Make a simple API call to trigger token refresh if needed
      gitlab_integration.user_info
      # Schedule the next keepalive
      re_enqueue(gitlab_integration_id, 6.hours)
    rescue Installations::Error => e
      if e.reason == :token_refresh_failure
        # Don't reschedule - the integration will be disconnected by existing logic
        elog(e, level: :warn)
      else
        elog(e, level: :error)
        re_enqueue(gitlab_integration_id, 1.hour)
      end
    rescue => e
      elog(e, level: :error)
      re_enqueue(gitlab_integration_id, 1.hour)
    end

    def re_enqueue(id, wait)
      self.class.perform_in(wait, id)
    end
  end
end
