class Services::PostRelease
  class AlmostTrunk
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
      end
    end

    private

    attr_reader :train, :release

    def update_status
      release.status = Releases::Train::Run.statuses[:finished]
      release.completed_at = Time.current
      release.save
    end

    def create_tag
      Automatons::Tag.dispatch!(train:, branch: release.branch_name)
    rescue Octokit::UnprocessableEntity
      nil
    end
  end
end
