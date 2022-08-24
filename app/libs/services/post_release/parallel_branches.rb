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
      transaction do
        update_status
        create_tag
        merge_prs
      end
    end

    private

    attr_reader :train, :release

    def update_status
      release.status = Releases::Train::Run.statuses[:finished]
      release.completed_at = Time.current
      release.save
    end

    def merge_prs
      response =
        repo_integration
          .create_pr!(repository_name, train.working_branch, train.release_branch, pr_title, pr_description)
      repo_integration.merge_pr!(repository_name, response[:number])
    end

    def create_tag
      Automatons::Tag.dispatch!(train:, branch: release.branch_name)
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
