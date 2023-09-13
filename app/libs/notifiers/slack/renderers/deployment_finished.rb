module Notifiers
  module Slack
    class Renderers::DeploymentFinished < Renderers::Base
      TEMPLATE_FILE = "deployment_finished.json.erb".freeze

      def sanitized_build_notes
        safe_string("*Build notes*\n```#{@build_notes}```")
      end

      def sanitized_release_notes
        safe_string(":spiral_note_pad: *What's New*\n\n```#{@release_notes}```")
      end
    end
  end
end
