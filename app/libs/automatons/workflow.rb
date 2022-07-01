module Automatons
  class Workflow
    class DispatchFailure < StandardError; end

    attr_reader :step, :ref, :github_api, :release

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(step:, ref:, release:)
      @step = step
      @ref = ref
      @release = release
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      unless github_api.run_workflow!(code_repository, ci_cd_channel, ref, inputs)
        raise DispatchFailure, "Failed to kickoff the workflow!"
      end
    end

    private

    def inputs
      {
        versionCode: step.app.bump_build_number!.to_s,
        versionName: release.release_version
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
