module Notifiers
  module Slack
    class Renderers::ProductionSubmissionStarted < Renderers::Base
      TEMPLATE_FILE = "production_submission_started.json.erb".freeze

      def sanitized_release_notes
        safe_string(":spiral_note_pad: *What's New*\n\n```#{@release_notes}```")
      end
    end
  end
end
