module Notifiers
  module Slack
    class DeploymentCompleted < Base
      include Rails.application.routes.url_helpers

      TEMPLATE_FILE = "deployment_completed.json.erb"

      def initialize(release:)
        @release = release
        @version_number = version_number
        @train_name = train_name
        @artifact_download_link = artifact_download_link
        super
      end

      private

      def train_name
        @release.train.name
      end

      def artifact_download_link
        if @release.final_artifact_file.present?
          _artifact_download_link
        else
          fallback_link
        end
      end

      def _artifact_download_link
        if Rails.env.development?
          rails_blob_url(@release.final_artifact_file, host: ENV["HOST_NAME"], port: ENV["PORT_NUM"], protocol: "https", disposition: "attachment")
        else
          rails_blob_url(@release.final_artifact_file, protocol: "https", disposition: "attachment")
        end
      end

      def fallback_link
        if Rails.env.development?
          release_url(@release, host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"])
        else
          release_url(@release, host: ENV["HOST_NAME"], protocol: "https")
        end
      end

      def version_number
        @release.train.version_current
      end

      def template_file
        File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
      end
    end
  end
end
