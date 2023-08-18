module Notifiers
  module Slack
    class Renderers::DeploymentFinished < Renderers::Base
      TEMPLATE_FILE = "deployment_finished.json.erb".freeze

      def sanitized_build_notes
        '*Build notes*\n```' + @build_notes.gsub(/"/, '\\"').gsub("\n", '\\\n') + "```"
      end
    end
  end
end
