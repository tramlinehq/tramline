module Automatons
  class Workflow
    class DispatchFailure < StandardError; end

    attr_reader :step, :ref, :github_api, :step_run

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(step:, ref:, step_run:)
      @step = step
      @ref = ref
      @step_run = step_run
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      if github_api.run_workflow!(code_repository, ci_cd_channel, ref, inputs)
        last_workflow_run = github_api.workflow_runs(code_repository, ci_cd_channel, {
          branch: ref,
          event: "workflow_dispatch",
          actor: github_bot_name,
          per_page: 1
        })[:workflow_runs].first
        # NOTE: Unfortunately github is not giving us the newly created workflow run with workflow dispatch api call
        # This is workaround to get last workflow dispatch created from the same branch, there is a scope of race condition here
        step_run.update!(ci_ref: last_workflow_run[:id], ci_link: last_workflow_run[:html_url])
      else
        raise DispatchFailure, "Failed to kickoff the workflow!"
      end
    end

    private

    def inputs
      {
        versionCode: step.app.bump_build_number!.to_s,
        versionName: step_run.build_version
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
        .code_repository_name
    end

    def installation_id
      step
        .app
        .ci_cd_provider
        .installation_id
    end

    def github_bot_name
      if Rails.env.production?
        "tramline[bot]"
      else
        "tramline-dev[bot]"
      end
    end
  end
end
