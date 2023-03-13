module Installations
  module Errors
    PullRequestNotMergeable = Class.new(StandardError)
    TagReferenceAlreadyExists = Class.new(StandardError)
    TaggedReleaseAlreadyExists = Class.new(StandardError)
    PullRequestAlreadyExists = Class.new(StandardError)
    PullRequestWithoutCommits = Class.new(StandardError)
    HookAlreadyExistsOnRepository = Class.new(StandardError)
    ResourceNotFound = Class.new(StandardError)
    WorkflowRunNotFound = Class.new(StandardError)
    WorkflowTriggerFailed = Class.new(StandardError)

    class WebhookLimitReached < StandardError
      def initialize(msg = "We can't create any more webhooks in your VCS/CI environment!")
        super
      end
    end
  end
end
