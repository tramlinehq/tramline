module Notifiers
  module Slack
    class Renderers::StagedRolloutFullyReleased < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        "Your staged rollout has been accelerated to a *full release to all users* from stage #{@current_stage} (#{@rollout_percentage}%)."
      end

      def secondary_text = nil
    end
  end
end
