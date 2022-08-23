module Notifiers
  module Slack
    class BuildFinished < Base
      TEMPLATE_FILE = "build_finished.json.erb"
      RUN_URI =
        Addressable::Template.new("https://api.github.com/repos/{org_name}/{repo_name}/actions/runs/{run_id}/artifacts")

      def initialize(artifact_link:, code_name:, build_number:, version_number:, branch_name:)
        @code_name = code_name
        @branch_name = branch_name
        @build_number = build_number
        @version_number = version_number
        @artifact_link = artifact_link(artifact_link)
        super
      end

      private

      def artifact_link(link)
        extracted = RUN_URI.extract(link)
        "https://github.com/#{extracted["org_name"]}/#{extracted["repo_name"]}/actions/runs/#{extracted["run_id"]}"
      end
    end
  end
end
