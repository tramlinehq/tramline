module Notifiers
  module Slack
    class Renderers::StagedRolloutPaused < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        "Staged rollout for the release was *paused* at *#{@current_stage} (#{@rollout_percentage}%)*"
      end

      def secondary_text
        "You can choose to *Resume* or *Halt* your release from the live release page"
      end
    end
  end
end
