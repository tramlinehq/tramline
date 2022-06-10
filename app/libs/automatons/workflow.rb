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
      raise DispatchFailure, "Failed to kickoff the workflow!" unless github_api.run_workflow!(code_repository, ci_cd_channel, ref, inputs)
    end

    private

    def inputs
      {
        versionCode: step.app.bump_build_number!.to_s,
        versionName: step.train.bump_version!.to_s
      }
    end

    def ci_cd_channel
      step
        .ci_cd_channel
        .keys
        .first
    end

    def code_repository
      step
        .app
        .config
        .code_repository
        .values
        .first
    end

    def installation_id
      step
        .app
        .ci_cd_provider
        .installation_id
    end
  end
end
