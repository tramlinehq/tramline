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

    # play store errors
    BuildExistsInBuildChannel = Class.new(StandardError)
    BundleIdentifierNotFound = Class.new(StandardError)
    BuildNotUpgradable = Class.new(StandardError)
    DuplicatedBuildUploadAttempt = Class.new(StandardError)
    GooglePlayDeveloperAPIDisabled = Class.new(StandardError)
    GooglePlayDeveloperAPIPermissionDenied = Class.new(StandardError)
    GooglePlayDeveloperAPIInvalidPackage = Class.new(StandardError)
    GooglePlayDeveloperAPIAPKsAreNotAllowed = Class.new(StandardError)

    # app store errors
    AppNotFoundInStore = Class.new(StandardError)
    BuildNotFoundInStore = Class.new(StandardError)
    BetaGroupNotFound = Class.new(StandardError)
    ReleaseNotFoundInStore = Class.new(StandardError)
    ReleaseAlreadyExists = Class.new(StandardError)
    AppStoreBuildNotSubmittable = Class.new(StandardError)
    AppStoreReviewSubmissionNotAllowed = Class.new(StandardError)
    AppStoreBuildMismatch = Class.new(StandardError)
    AppStoreReviewInProgress = Class.new(StandardError)
    AppStoreReviewSubmissionExists = Class.new(StandardError)
    PhasedReleaseNotFound = Class.new(StandardError)

    class WebhookLimitReached < StandardError
      def initialize(msg = "We can't create any more webhooks in your VCS/CI environment!")
        super
      end
    end
  end
end
