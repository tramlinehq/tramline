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

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)
    attr_reader :train, :release
    delegate :fully_qualified_release_branch_hack, :working_branch, to: :train

    def create_and_merge_pr
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: fully_qualified_release_branch_hack,
        title: pr_title,
        description: pr_description
      )
    end

    def create_tag
      begin
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        release.event_stamp!(reason: :tagged_release_already_exists, kind: :notice, data: { tag: release.tag_name })
      end

      Result.new(ok?: true)
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
