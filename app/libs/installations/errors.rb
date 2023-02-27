module Installations
  module Errors
    PullRequestNotMergeable = Class.new(StandardError)
    TagReferenceAlreadyExists = Class.new(StandardError)
    TaggedReleaseAlreadyExists = Class.new(StandardError)
    PullRequestAlreadyExists = Class.new(StandardError)
    PullRequestWithoutCommits = Class.new(StandardError)
    HookAlreadyExistsOnRepository = Class.new(StandardError)
    ResourceNotFound = Class.new(StandardError)
    BuildExistsInBuildChannel = Class.new(StandardError)
    WorkflowRunNotFound = Class.new(StandardError)
    BuildNotFoundInStore = Class.new(StandardError)
    ReleaseNotFoundInStore = Class.new(StandardError)
    AppCurrentStatusNotFoundInStore = Class.new(StandardError)
    SubmissionCreationError = Class.new(StandardError)
    AppNotFoundInStore = Class.new(StandardError)
    WorkflowTriggerFailed = Class.new(StandardError)
    BundleIdentifierNotFound = Class.new(StandardError)
    BuildNotUpgradable = Class.new(StandardError)
    DuplicatedBuildUploadAttempt = Class.new(StandardError)
    GooglePlayDeveloperAPIDisabled = Class.new(StandardError)
    GooglePlayDeveloperAPIPermissionDenied = Class.new(StandardError)
    GooglePlayDeveloperAPIInvalidPackage = Class.new(StandardError)
    GooglePlayDeveloperAPIAPKsAreNotAllowed = Class.new(StandardError)

    class WebhookLimitReached < StandardError
      def initialize(msg = "We can't create any more webhooks in your VCS/CI environment!")
        super
      end
    end
  end
end
