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

    delegate :installation_id, to: :version_control

    def code_repo
      version_control
        .active_code_repo
        .values
        .first
    end

    def version_control
      train
        .integrations
        .version_control
        .first
    end
  end
end
