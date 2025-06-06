module Notifiers
  module Slack
    class Renderers::ProductionRolloutStarted < Renderers::Base
      TEMPLATE_FILE = "production_rollout_started.json.erb".freeze

      def staged_rollout_started_text
        if @requires_review
          "The rollout for release *#{@release_version} (#{@build_number})* has *started*."
        else
          "The release *#{@release_version} (#{@build_number})* has been *sent for review*."
        end
      end

      def initial_rollout_percentage_text
        "🎢 Initial rollout percentage is *#{@rollout_percentage}%*."
      end
    end
  end
end
