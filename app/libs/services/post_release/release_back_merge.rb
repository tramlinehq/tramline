class Services::PostRelease
  class ReleaseBackMerge
    delegate :transaction, to: ApplicationRecord

    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      release.mark_finished! if create_tag.success? && create_and_merge_prs.success?
    end

    private

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)

    attr_reader :train, :release

    # TODO: Fix from branch to be fully qualified
    def create_and_merge_prs
      Automatons::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: train.release_backmerge_branch,
        from_branch_ref: release.branch_name,
        title: "Pre-release merge",
        description: "Merging this before starting release."
      )

      Automatons::PullRequest.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: train.working_branch,
        from_branch_ref: train.release_backmerge_branch,
        title: "Pre-release merge",
        description: "Merging this before starting release."
      )
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
      "Release PR"
    end

    def pr_description
      <<~TEXT
        Verbose description for #{train.name} release on #{release.was_run_at}
      TEXT
    end
  end
end
