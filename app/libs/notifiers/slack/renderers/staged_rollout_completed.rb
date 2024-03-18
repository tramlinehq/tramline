module Notifiers
  module Slack
    class Renderers::StagedRolloutCompleted < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        "Staged rollout for the release is now *complete* at stage *#{@current_stage} (#{@rollout_percentage}%)*."
      end

      def secondary_text
        "The rollout on this release is now locked on Tramline and cannot be altered further."
      end
    end
  end
end
