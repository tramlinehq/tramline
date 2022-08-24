module Notifiers
  module Slack
    class ReleaseStarted < Base
      TEMPLATE_FILE = "release_started.json.erb"

      def initialize(train_name:, version_number:, branch_name:, commit_msg:)
        @train_name = train_name
        @commit_msg = commit_msg
        @branch_name = branch_name
        @version_number = version_number
        super
      end

      private

      def template_file
        File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
      end
    end
  end
end
