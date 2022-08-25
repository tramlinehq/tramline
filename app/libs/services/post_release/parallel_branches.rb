class Services::PostRelease
  class ParallelBranches
    delegate :transaction, to: ApplicationRecord

    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      release.mark_finished! if create_tag.success? && create_and_merge_pr.success?
    end

    private

    Result = Struct.new(:success?, :err_message)

    delegate :release_branch, :fully_qualified_release_branch_hack, :working_branch, to: train
    attr_reader :train, :release

    def create_and_merge_pr
      pull_request =
        release
          .pull_requests
          .post_release
          .open
          .build
          .update_or_insert!(pull_request_at_source)

      if merge_pr.success?
        pull_request.close!
        Result.new(true)
      else
        Result.new(false, "Failed to merge the Pull Request")
      end
    end

    def pull_request_at_source
      @pull_request_at_source ||=
        begin
          repo_integration.create_pr!(repository_name, working_branch, release_branch, pr_title, pr_description)
        rescue Installations::Github::Error::PullRequestAlreadyExistsError
          release.event_stamp!(reason: :post_release_pull_request_already_exists, kind: :notice, data: {})
          repo_integration.find_pr(repository_name, working_branch, fully_qualified_release_branch_hack)
        end
    end

    def merge_pr
      repo_integration.merge_pr!(repository_name, pull_request_at_source[:number])
      Result.new(true)
    rescue Installations::Github::Error::PullRequestNotMergeableError
      release.event_stamp!(reason: :post_release_pull_request_not_mergeable, kind: :notice, data: {})
      Result.new(false, "Failed to merge the Pull Request")
    end

    def create_tag
      Automatons::Tag.dispatch!(train:, branch: release.branch_name)
    rescue Installations::Github::Error::ReferenceAlreadyExists
      release.event_stamp!(reason: :post_release_tag_reference_already_exists, kind: :notice, data: {})
    ensure
      Result.new(true)
    end

    def repository_name
      train.app.config.code_repository_name
    end

    def repo_integration
      train.vcs_provider.installation
    end

    def pr_title
      "[Release kickoff] #{release.release_version}"
    end

    def pr_description
      <<~TEXT
        New release train #{train.name} triggered.
        The #{working_branch} branch has been merged into #{release.branch_name} branch, as per #{train.branching_strategy_name} branching strategy.
      TEXT
    end
  end
end
