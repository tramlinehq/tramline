module Seed
  class MockTrain < Train
    def workflows
      @mock_workflows ||= [
        {id: "build", name: "Build"},
        {id: "test", name: "Test"},
        {id: "deploy", name: "Deploy"}
      ]
    end

    def create_release_platforms
    end

    def create_default_notification_settings
    end

    def create_release_index
    end

    def fetch_ci_cd_workflows
    end

    def set_current_version
    end

    def set_default_status
    end

    def version_compatibility
    end

    def ci_cd_workflows_presence
    end

    def working_branch_presence
    end
  end
end
