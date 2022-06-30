class Services::PostRelease
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
    @train = release.train
  end

  def call
    update_status

    if train.branching_strategy == "release_backmerge"

      response = begin
        repo_integration.create_pr!(repository_name, train.release_backmerge_branch, release.branch_name, backmerge_pr_title, backmerge_pr_description)
      rescue
        nil
      end
      begin
        repo_integration.merge_pr!(repository_name, response[:number])
      rescue
        nil
      end

      response = repo_integration.create_pr!(repository_name, train.working_branch, train.release_backmerge_branch, backmerge_pr_title, backmerge_pr_description)

      repo_integration.merge_pr!(repository_name, response[:number])

    end
    create_tag
  end

  private

  attr_reader :train, :release

  def update_status
    release.status = Releases::Train::Run.statuses[:finished]
    release.completed_at = Time.current
    release.save
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

  def backmerge_pr_title
    "Release PR"
  end

  def backmerge_pr_description
    <<~TEXT
      Verbose description for #{train.name} release on #{release.was_run_at}
    TEXT
  end
end
