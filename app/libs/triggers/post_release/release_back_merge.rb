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
      end.then do |value|
        release.reload.pull_requests.post_release.each do |pr|
          release.event_stamp!(reason: :post_release_pr_succeeded, kind: :success, data: {url: pr.url, number: pr.number})
        end
        GitHub::Result.new { value }
      end
    end

    def create_tag
      GitHub::Result.new do
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        Rails.logger.debug { "Release finalization: did not create tag, since #{train.tag_name} already existed" }
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        Rails.logger.debug { "Release finalization: skipping since tagged release for #{train.tag_name} already exists!" }
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
