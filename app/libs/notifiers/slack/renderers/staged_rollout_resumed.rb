module Notifiers
  module Slack
    class Renderers::StagedRolloutResumed < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        "Staged rollout for the release was *resumed* at *#{@current_stage} (#{@rollout_percentage}%)*."
      end

      def secondary_text
        "You can choose to *Pause* or *Halt* your release from the live release page."
      end
    end
  end
end
