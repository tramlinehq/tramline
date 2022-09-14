module Notifiers
  module Slack
    class BuildFinished < Base
      TEMPLATE_FILE = "build_finished.json.erb"
      RUN_URI =
        Addressable::Template.new("https://api.github.com/repos/{org_name}/{repo_name}/actions/runs/{run_id}/artifacts")

      def initialize(artifacts_url:, code_name:, build_number:, version_number:, branch_name:)
        @code_name = code_name
        @branch_name = branch_name
        @build_number = build_number
        @version_number = version_number
        @artifacts_url = artifacts_url(artifacts_url)
        super
      end

      private

      def artifacts_url(url)
        extracted = RUN_URI.extract(url)
        "https://github.com/#{extracted["org_name"]}/#{extracted["repo_name"]}/actions/runs/#{extracted["run_id"]}"
      end

      def template_file
        File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
      end
    end
  end
end
