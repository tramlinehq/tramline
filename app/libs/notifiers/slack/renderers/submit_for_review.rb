module Notifiers
  module Slack
    class Renderers::SubmitForReview < Renderers::Base
      TEMPLATE_FILE = "submit_for_review.json.erb".freeze

      def sanitized_release_notes
        safe_string(":spiral_note_pad: *What's New*\n\n```#{@release_notes}```")
      end

      def submitted_text
        return "resubmitted" if @resubmission
        "submitted"
      end
    end
  end
end
