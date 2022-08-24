class Services::PostRelease
  class ParallelBranches
    class PostReleaseFailed < StandardError; end
    delegate :transaction, to: ApplicationRecord

    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      transaction do
        create_tag
        create_and_merge_prs
        release.mark_finished!
      end
    end

    private

    attr_reader :train, :release

    def create_and_merge_prs
      begin
        response =
          repo_integration
            .create_pr!(repository_name, train.working_branch, train.release_branch, pr_title, pr_description)
      rescue Installations::Github::Error::PullRequestAlreadyExistsError
        train_run.event_stamp!(reason: :post_release_pull_request_already_exists, kind: :notice, data: {})
        raise PostReleaseFailed.new
      end

      begin
        repo_integration.merge_pr!(repository_name, response[:number])
      rescue Installations::Github::Error::PullRequestNotMergeableError
        train_run.event_stamp!(reason: :post_release_pull_request_not_mergeable, kind: :notice, data: {})
        raise PostReleaseFailed.new
      end
    end

    def create_tag
      Automatons::Tag.dispatch!(train:, branch: release.branch_name)
    rescue Installations::Github::Error::ReferenceAlreadyExists
      nil
    end

    def repo_integration
      train.ci_cd_provider.installation
    end

    def repository_name
      train.app.config.code_repository_name
    end

    def pr_title
      "[Release kickoff] #{release.release_version}"
    end

    def pr_description
      <<~TEXT
        New release train #{train.name} triggered.
        The #{train.working_branch} branch has been merged into #{release.branch_name} branch, as per #{train.branching_strategy_name} branching strategy.
      TEXT
    end
  end
end
