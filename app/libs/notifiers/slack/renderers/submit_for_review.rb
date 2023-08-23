module Notifiers
  module Slack
    class Renderers::SubmitForReview < Renderers::Base
      TEMPLATE_FILE = "submit_for_review.json.erb".freeze

      def sanitized_release_notes
        safe_string(":spiral_note_pad: What's New\n\n```#{@release_notes}```")
      end

      def google_managed_publishing_text
        "- If managed publishing is disabled, this update will auto-start the rollout upon approval by Google."
      end

      def google_unmanaged_publishing_text
        "- If managed publishing is enabled, you'll need to manually release this update through the Play Store."
      end

      def apple_publishing_text
        "- Releases from Tramline are always manually released, you can start the release to users once it is approved from the Live Release page."
      end
    end
  end
end
