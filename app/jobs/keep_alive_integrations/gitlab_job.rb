module KeepAliveIntegrations
  class GitlabJob < ApplicationJob
    queue_as :default

    def perform(gitlab_integration_id)
      gitlab_integration = GitlabIntegration.find(gitlab_integration_id)
      return unless gitlab_integration.integration.connected?

      # Make a simple API call to trigger token refresh if needed
      gitlab_integration.metadata
      Rails.logger.info "GitLab token keepalive successful for integration #{gitlab_integration_id}"

      # Schedule the next keepalive
      re_enqueue(gitlab_integration_id, 6.hours)
    rescue Installations::Error => e
      if e.reason == :token_refresh_failure
        Rails.logger.warn "GitLab token keepalive failed - tokens expired for integration #{gitlab_integration_id}"
        # Don't reschedule - the integration will be disconnected by existing logic
      else
        Rails.logger.error "GitLab token keepalive error for integration #{gitlab_integration_id}: #{e.message}"
        re_enqueue(gitlab_integration_id, 1.hour)
      end
    rescue => e
      Rails.logger.error "Unexpected error in GitLab token keepalive for integration #{gitlab_integration_id}: #{e.message}"
      elog(e, level: :error)
      re_enqueue(gitlab_integration_id, 1.hour)
    end

    def re_enqueue(id, wait)
      self.class.set(wait: wait).perform_async(id)
    end
  end
end
