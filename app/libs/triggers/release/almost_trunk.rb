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
      true
    end

    private

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)

    attr_reader :release, :release_branch
    delegate :train, to: :release
    delegate :fully_qualified_working_branch_hack, :working_branch, to: :train

    def create_branches
      train.create_branch!(working_branch, release_branch)
    rescue Octokit::UnprocessableEntity
      nil
    end
  end
end
