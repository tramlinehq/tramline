module Notifiers
  module Slack
    class BuildFinished < Base
      TEMPLATE_FILE = "build_finished.json.erb"

      def initialize(artifacts_url:, code_name:, build_number:, version_number:, branch_name:)
        @code_name = code_name
        @branch_name = branch_name
        @build_number = build_number
        @version_number = version_number
        @artifacts_url = artifacts_url
        super
      end

      private

      def template_file
        File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
      end
    end
  end
end
