module Automatons
  class Workflow
    attr_reader :integration, :github_api, :step

    delegate :ci_cd_channel, to: :step
    delegate :installation_id, to: :integration
    delegate :active_code_repo, to: :integration

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(step:, integration:)
      @step = step
      @integration = integration
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      github_api.run_workflow!(active_code_repo.values.first, step.ci_cd_channel.keys.first, "main")
    end
  end
end
