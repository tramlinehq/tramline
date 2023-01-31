module Installations
  module Errors
    class TagReferenceAlreadyExists < StandardError; end

    class TaggedReleaseAlreadyExists < StandardError; end

    class PullRequestNotMergeable < StandardError; end

    class WebhookLimitReached < StandardError
      def initialize(msg = "We can't create any more webhooks in your VCS/CI environment!")
        super
      end
    end

    class PullRequestAlreadyExists < StandardError; end

    class PullRequestWithoutCommits < StandardError; end

    class HookAlreadyExistsOnRepository < StandardError; end

    class ResourceNotFound < StandardError; end

    class BuildExistsInBuildChannel < StandardError; end

    class WorkflowRunNotFound < StandardError; end

    class BuildNotFoundInStore < StandardError; end

    class AppNotFoundInStore < StandardError; end

    class WorkflowTriggerFailed < StandardError; end

    class BundleIdentifierNotFound < StandardError; end

    class BuildNotUpgradable < StandardError; end

    class DuplicatedBuildUploadAttempt < StandardError; end

    class GooglePlayDeveloperAPIDisabled < StandardError; end

    class GooglePlayDeveloperAPIPermissionDenied < StandardError; end

    class GooglePlayDeveloperAPIInvalidPackage < StandardError; end

    class GooglePlayDeveloperAPIAPKsAreNotAllowed < StandardError; end
  end
end
