class Services::PostRelease
  class AlmostTrunk
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
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

    def create_tag
      Automatons::Tag.dispatch!(
        train:,
        branch: release.branch_name
      )
    rescue Octokit::UnprocessableEntity
      nil
    end

    def repo_integration
      train.ci_cd_provider.installation
    end

    def repository_name
      train.app.config.code_repository_name
    end
  end
end
