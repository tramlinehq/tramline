module Notifiers
  module Slack
    class Renderers::ReviewApproved < Renderers::Base
      TEMPLATE_FILE = "review_approved.json.erb".freeze

      def google_managed_publishing_text
        "- If managed publishing is disabled, this update will auto-start the rollout upon approval by Google."
      end

      def google_unmanaged_publishing_text
        "- If managed publishing is enabled, you'll need to manually release this update through the Play Store."
      end

      def apple_publishing_text
        "- Releases from Tramline are always manually released, you can start the release to users from the Live Release page."
      end
    end
  end
end
