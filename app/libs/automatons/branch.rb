module Automatons
  class Branch
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
      unless github_api.create_branch!(code_repository, working_branch, branch)
        raise DispatchFailure, "Failed to kickoff the workflow!"
      end
    end

    private

    delegate :installation_id, to: :version_control
    delegate :working_branch, to: :config

    def code_repository
      config
        .code_repository
        .values
        .first
    end

    def config
      train.app.config
    end

    def version_control
      train
        .app
        .vcs_provider
    end
  end
end
