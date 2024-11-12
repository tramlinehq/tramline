module Actions
  module Webhooks
    class MonitorCommits < Action
      def initialize(train, payload)
        @train = train
        @payload = payload
      end

      def call
        return success(:accepted) unless valid_branch_push?
        return success(:accepted, message: "Branch not monitored") unless monitored_branch?

        Webhooks::CommitMonitorJob.perform_later(
          repository_name,
          branch_name,
          head_commit,
          rest_commits
        )

        success(:accepted)
      end

      private

      attr_reader :train, :payload

      delegate :vcs_provider, to: :train

      memoize def runner
        return Coordinators::Webhooks::Github::Commit.new(payload) if vcs_provider.integration.github_integration?
        return Coordinators::Webhooks::Gitlab::Push.new(payload, train) if vcs_provider.integration.gitlab_integration?
        Coordinators::Webhooks::Bitbucket::Push.new(payload, train) if vcs_provider.integration.bitbucket_integration?
      end

      delegate :branch_name, :repository_name, :valid_branch?, :valid_tag?, :head_commit, :rest_commits, to: :runner

      def valid_branch_push?
        valid_branch? && !valid_tag?
      end

      def monitored_branch?
        # Configure which branches to monitor
        branch_name == "main" # or your target branch
      end
    end
  end
end 