module Notifiers
  module Slack
    class Renderers::StagedRolloutCompleted < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        "Staged rollout for the release is now *complete*"
      end

      def secondary_text
        "You can not change this release from Tramline any more as it is locked."
      end
    end
  end
end
