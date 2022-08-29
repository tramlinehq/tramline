class Services::PostRelease
  class ReleaseBackMerge
    delegate :transaction, to: ApplicationRecord
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
      release.reload.mark_finished! if create_tag.ok? && create_and_merge_prs.ok?
    end

    private

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)

    attr_reader :train, :release

    def create_and_merge_prs
      Automatons::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: release_backmerge_branch,
        from_branch_ref: fully_qualified_branch_name_hack,
        title: pr_title,
        description: pr_description
      ).ok? &&
        Automatons::PullRequest.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.post_release.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: fully_qualified_release_backmerge_branch_hack,
          title: pr_title,
          description: pr_description
        ).ok? ? Result.new(ok?: true) : Result.new(ok?: false)
    end

    def create_tag
      begin
        Automatons::Tag.dispatch!(train:, branch: release.branch_name)
      rescue Installations::Github::Error::ReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      end

      Result.new(ok?: true)
    end

    def pr_title
      "[Release PR] #{release.release_version}"
    end

    def pr_description
      <<~TEXT
        Verbose description for #{train.name} release on #{release.was_run_at}
      TEXT
    end
  end
end
