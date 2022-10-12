module Notifiers
  module Slack
    class DeploymentFinished < Base
      include Rails.application.routes.url_helpers

      TEMPLATE_FILE = "deployment_finished.json.erb"

      def initialize(step_run:)
        @step_run = step_run
        @step_name = step_run.step.name
        @train_run = @step_run.train_run
        @version_number = version_number
        @train_name = train_name
        @artifact_download_link = artifact_download_link
        super
      end

      private

      def train_name
        @train_run.train.name
      end

      def artifact_download_link
        @step_run.build_artifact.download_url.presence || fallback_link
      end

      def fallback_link
        if Rails.env.development?
          release_url(@train_run, host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"])
        else
          release_url(@train_run, host: ENV["HOST_NAME"], protocol: "https")
        end
      end

      def version_number
        @step_run.build_version
      end

      def template_file
        File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
      end
    end
  end
end
