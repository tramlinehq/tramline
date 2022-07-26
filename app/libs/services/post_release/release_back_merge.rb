class Services::PostRelease
  class ReleaseBackMerge
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      merge_prs
      create_tag
      update_status
    end

    private

    attr_reader :train, :release

    def update_status
      release.status = Releases::Train::Run.statuses[:finished]
      release.completed_at = Time.current
      release.save
    end

    def merge_prs
      response = repo_integration.create_pr!(repository_name, train.release_backmerge_branch, release.branch_name, pr_title,
        pr_description)
      repo_integration.merge_pr!(repository_name, response[:number])

      response = repo_integration.create_pr!(repository_name, train.working_branch, train.release_backmerge_branch,
        pr_title, pr_description)

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
      "[Release kickoff] #{release.release_version}"
    end

    def pr_description
      <<~TEXT
        New release train #{train.name} triggered.
      TEXT
    end
  end
end
