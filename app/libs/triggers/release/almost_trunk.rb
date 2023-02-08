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
        train.create_branch!(working_branch, release_branch).then do |value|
          release.event_stamp!(reason: :release_branch_created, kind: :success, data: {working_branch:, release_branch:})
          GitHub::Result.new { value }
        end
      rescue Installations::Errors::TagReferenceAlreadyExists
        logger.debug { "Release creation: did not create branch, since #{release_branch} already existed" }
      end
    end
  end
end
