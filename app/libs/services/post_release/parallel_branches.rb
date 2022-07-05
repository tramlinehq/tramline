class Services::PostRelease
  class ParallelBranches
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      update_status
      create_tag
      merge_prs
    end

    private

    attr_reader :train, :release

    def update_status
      release.status = Releases::Train::Run.statuses[:finished]
      release.completed_at = Time.current
      release.save
    end

    def merge_prs
      response = repo_integration.create_pr!(repository_name, train.working_branch, train.release_branch, pr_title,
        pr_description)

      repo_integration.merge_pr!(repository_name, response[:number])
    end

    def create_tag
      Automatons::Tag.dispatch!(
        train:,
        branch: release.branch_name
      )
    end

    def repo_integration
      train.ci_cd_provider.installation
    end

    def repository_name
      train.app.config.code_repository_name
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
