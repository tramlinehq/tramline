module Notifiers
  module Slack
    class Renderers::StagedRolloutHalted < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        "Staged rollout for the release was *halted* at *#{@current_stage} (#{@rollout_percentage}%)*"
      end

      def secondary_text
        "You can not change this release from Tramline any more"
      end
    end
  end
end
