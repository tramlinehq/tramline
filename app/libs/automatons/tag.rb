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
      unless github_api.create_tag!(code_repo, train.tag_name, branch)
        raise DispatchFailure, "Failed to kickoff the workflow!"
      end
    end

    private

    def code_repo
      train
        .app
        .config
        .code_repository_name
    end

    def installation_id
      train
        .app
        .vcs_provider
        .installation_id
    end
  end
end
