module Notifiers
  module Slack
    class Renderers::DeploymentFinished < Renderers::Base
      TEMPLATE_FILE = "deployment_finished.json.erb".freeze

      def initialize(**params)
        @step_run = params[:step_run]
        @step_name = @step_run.step.name
        @train_run = @step_run.train_run
        @version_number = @step_run.build_version
        @train_name = @train_run.train.name
        @artifact_download_link = artifact_download_link
        super
      end

      private

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
    end
  end
end
