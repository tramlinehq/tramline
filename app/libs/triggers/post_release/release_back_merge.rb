class Triggers::PostRelease
  class ReleaseBackMerge
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      release.reload.finish! if create_tag.ok? && create_and_merge_prs.ok?
    end

    private

    attr_reader :train, :release
    delegate :vcs_provider, :release_backmerge_branch, :working_branch, to: :train
    delegate :branch_name, to: :release

    def create_and_merge_prs
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: release_backmerge_branch,
        from_branch_ref: namespaced_release_branch,
        title: release_pr_title,
        description: pr_description
      ).then do |_|
        Triggers::PullRequest.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.post_release.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: namespaced_backmerge_branch,
          title: backmerge_pr_title,
          description: pr_description
        )
      end
    end

    def create_tag
      GitHub::Result.new do
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        release.event_stamp!(reason: :tagged_release_already_exists, kind: :notice, data: {tag: release.tag_name})
      end
    end

    def namespaced_backmerge_branch
      vcs_provider.namespaced_branch(release_backmerge_branch)
    end

    def namespaced_release_branch
      vcs_provider.namespaced_branch(branch_name)
    end

    def release_pr_title
      "[#{release.release_version}] Merge to finalize release"
    end

    def backmerge_pr_title
      "[#{release.release_version}] Backmerge to working branch"
    end

    def pr_description
      <<~TEXT
        Verbose description for #{train.name} release on #{release.scheduled_at}
      TEXT
    end
  end
end
