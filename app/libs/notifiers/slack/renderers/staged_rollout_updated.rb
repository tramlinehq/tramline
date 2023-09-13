module Notifiers
  module Slack
    class Renderers::StagedRolloutUpdated < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze

      def main_text
        if @is_fully_released
          "Your staged rollout is *complete*, and your update has rolled out to all users."
        else
          "Your staged rollout is *active*, and you are currently on stage *#{@current_stage} (#{@rollout_percentage}%)*."
        end
      end

      def secondary_text
        if @is_fully_released
          "View your release on the #{store}."
        else
          action_text
        end
      end

      def store
        if @is_app_store_production
          "App Store"
        elsif @is_play_store_production
          "Play Console"
        end
      end

      def action_text
        if @is_app_store_production
          "You can choose to *Pause*, *Halt*, or *Release to 100%*."
        elsif @is_play_store_production
          "You can choose to *Increase*, *Halt*, or *Release to 100%*."
        end
      end
    end
  end
end
