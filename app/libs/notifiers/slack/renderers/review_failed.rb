module Notifiers
  module Slack
    class Renderers::ReviewFailed < Renderers::Base
      TEMPLATE_FILE = "review_failed.json.erb".freeze

      def apple_review_failed_text
        "You can resolve the rejection from the App Store Connect, or, submit a new build for review."
      end
    end
  end
end
