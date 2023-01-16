class Triggers::Release
  class AlmostTrunk
    include ApplicationHelper

    def self.call(release, release_branch)
      new(release, release_branch).call
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call
      create_branches
    end

    private

    attr_reader :release, :release_branch
    delegate :train, to: :release
    delegate :working_branch, to: :train

    # TODO: this should be handled gracefully rather than catching a Github-specific error
    def create_branches
      GitHub::Result.new do
        train.create_branch!(working_branch, release_branch)
      rescue Octokit::UnprocessableEntity
        nil
      end
    end
  end
end
