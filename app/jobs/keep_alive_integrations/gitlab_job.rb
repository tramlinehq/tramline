module KeepAliveIntegrations
  class GitlabJob < BaseJob
    def providable_class = GitlabIntegration

    def keep_alive(gitlab_integration) = gitlab_integration.user_info
  end
end
