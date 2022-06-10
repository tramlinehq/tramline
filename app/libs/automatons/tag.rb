module Automatons
  class Tag
    class DispatchFailure < StandardError; end

    attr_reader :train, :branch, :github_api

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(train:, branch:)
      @train = train
      @branch = branch
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      raise DispatchFailure, "Failed to kickoff the workflow!" unless github_api.create_tag!(code_repo, train.tag_name, branch)
    end

    private

    def code_repo
      train
        .app
        .config
        .code_repository
        .values
        .first
    end

    def installation_id
      train
        .app
        .vcs_provider
        .installation_id
    end
  end
end
