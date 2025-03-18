class Triggers::PreRelease
  class ParallelBranches
    include ApplicationHelper

    def self.call(release, release_branch)
      new(release, release_branch).call
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call
      create_and_merge_pr
    end

    private

    attr_reader :release, :release_branch
    delegate :train, to: :release
    delegate :vcs_provider, :working_branch, to: :train

    def create_and_merge_pr
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.pre_release.open.build,
        to_branch_ref: release_branch,
        from_branch_ref: working_branch,
        title: pr_title,
        description: pr_description,
        allow_without_diff: false
      ).then do |value|
        pr = release.reload.pull_requests.pre_release.first
        release.event_stamp_now!(reason: :kickoff_pr_succeeded, kind: :success, data: {url: pr.url, number: pr.number})
        GitHub::Result.new { value }
      end
    end

    def pr_title
      "[#{version_in_progress(train.version_current)}] Pre-release merge"
    end

    def pr_description
      "A new release train #{train.name} is starting. The #{working_branch} branch has to be merged into #{release_branch} branch."
    end
  end
end
