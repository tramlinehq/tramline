module Notifiers
  module Slack
    class Renderers::ReviewApproved < Renderers::Base
      TEMPLATE_FILE = "review_approved.json.erb".freeze

      def apple_publishing_text
        "- Releases from Tramline are always manually released, you can start the release to users from the Live Release page."
      end
    end
  end
end
