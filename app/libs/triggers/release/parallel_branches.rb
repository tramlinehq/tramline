class Triggers::Release
  class ParallelBranches
    def self.call(release, release_branch)
      new(release, release_branch).call
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call
      create_and_merge_pr.ok?
    end

    private

    attr_reader :release, :release_branch
    delegate :fully_qualified_working_branch_hack, :working_branch, to: :train

    def create_and_merge_pr
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.pre_release.open.build,
        to_branch_ref: release_branch,
        from_branch_ref: fully_qualified_working_branch_hack,
        title: pr_title,
        description: "Merging this before starting release.",
        allow_without_diff: false
      )
    end

    def pr_title
      "[#{version_in_progress(train.version_current)}] Pre-release merge"
    end
  end
end
