class Triggers::PostRelease
  class ReleaseBackMerge
    delegate :fully_qualified_release_backmerge_branch_hack, :release_backmerge_branch, :working_branch, to: :train
    delegate :fully_qualified_branch_name_hack, to: :release

    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      release.reload.finish! if create_tag.ok? && create_release.ok? && create_and_merge_prs.ok?
    end

    private

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)
    attr_reader :train, :release
    delegate :tag_name, to: :train

    def create_and_merge_prs
      Triggers::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: release_backmerge_branch,
        from_branch_ref: fully_qualified_branch_name_hack,
        title: release_pr_title,
        description: pr_description
      ).ok? &&
        Triggers::PullRequest.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.post_release.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: fully_qualified_release_backmerge_branch_hack,
          title: backmerge_pr_title,
          description: pr_description
        ).ok? ? Result.new(ok?: true) : Result.new(ok?: false)
    end

    def create_tag
      begin
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      end

      Result.new(ok?: true)
    end

    def create_release
      begin
        train.create_release!(tag_name)
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        release.event_stamp!(reason: :tagged_release_already_exists, kind: :notice, data: { tag: tag_name })
      end

      Result.new(ok?: true)
    end

    def release_pr_title
      "[#{release.release_version}] Merge to finalize release"
    end

    def backmerge_pr_title
      "[#{release.release_version}] Backmerge to working branch"
    end

    def pr_description
      <<~TEXT
        Verbose description for #{train.name} release on #{release.was_run_at}
      TEXT
    end
  end
end
