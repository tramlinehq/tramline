module Installations
  module Errors
    class TagReferenceAlreadyExists < StandardError; end

    class PullRequestNotMergeable < StandardError; end

    class WebhookLimitReached < StandardError; end

    class PullRequestAlreadyExists < StandardError; end

    class PullRequestWithoutCommits < StandardError; end

    class HookAlreadyExistsOnRepository < StandardError; end

    class ResourceNotFound < StandardError; end

    class BuildExistsInBuildChannel < StandardError; end

    class WorkflowTriggerFailed < StandardError; end

    class WorkflowRunNotFound < StandardError; end

    class WorkflowTriggerFailed < StandardError; end
  end
end
