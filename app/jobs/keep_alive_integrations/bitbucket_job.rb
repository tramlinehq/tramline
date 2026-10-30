module KeepAliveIntegrations
  class BitbucketJob < BaseJob
    def providable_class = BitbucketIntegration

    def keep_alive(bitbucket_integration) = bitbucket_integration.metadata
  end
end
