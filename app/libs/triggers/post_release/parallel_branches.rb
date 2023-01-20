class Triggers::PostRelease
  class ParallelBranches
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      release.reload.finish! if create_tag.ok? && create_and_merge_pr.ok?
    end

    private

    attr_reader :train, :release
    delegate :vcs_provider, :release_branch, :working_branch, to: :train

    def create_and_merge_pr
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: namespaced_release_branch,
        title: pr_title,
        description: pr_description
      ).then do |value|
        pr = release.reload.pull_requests.post_release.first
        release.event_stamp!(reason: :post_release_pr_succeeded, kind: :success, data: {url: pr.url, number: pr.number})
        GitHub::Result.new { value }
      end
    end

    def create_tag
      GitHub::Result.new do
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {tag: release.tag_name})
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        release.event_stamp!(reason: :tagged_release_already_exists, kind: :notice, data: {tag: release.tag_name})
      end
    end

    def namespaced_release_branch
      vcs_provider.namespaced_branch(release_branch)
    end

    def pr_title
      "[#{release.release_version}] Post-release merge"
    end

    def pr_description
      <<~TEXT
        New release train #{train.name} triggered.
        The #{working_branch} branch has been merged into #{release.branch_name} branch, as per #{train.branching_strategy_name} branching strategy.
      TEXT
    end
  end
end
