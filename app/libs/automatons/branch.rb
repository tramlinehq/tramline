module Automatons
  class Branch
    class DispatchFailure < StandardError; end

    attr_reader :step, :branch, :github_api

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(step:, branch:)
      @step = step
      @branch = branch
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      unless github_api.create_branch!(code_repo, ref, branch)
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

    def integrations
      step
        .train
        .integrations
    end

    def version_control
      integrations
        .version_control
        .first
    end

    def ref
      version_control
        .working_branch
    end
  end
end
