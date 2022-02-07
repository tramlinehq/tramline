module Automatons
  class Workflow
    class DispatchFailure < StandardError; end

    attr_reader :step, :ref, :github_api

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(step:, ref:)
      @step = step
      @ref = ref
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      unless github_api.run_workflow!(code_repo, ci_cd_channel, ref)
        raise DispatchFailure, "Failed to kickoff the workflow!"
      end
    end

    private

    delegate :installation_id, to: :ci_cd

    def ci_cd_channel
      step
        .ci_cd_channel
        .keys
        .first
    end

    def code_repo
      ci_cd
        .active_code_repo
        .values
        .first
    end

    def integrations
      step
        .train
        .integrations
    end

    def ci_cd
      integrations
        .ci_cd
        .first
    end
  end
end
