module Notifiers
  module Slack
    class Renderers::StagedRolloutUpdated < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze
      def initialize(**params)
        super(**params)
        @main_text = main_text
        @secondary_text = secondary_text
      end

      def main_text
        if @is_fully_released
          "Your staged rollout is *complete*, and your update has rolled out to all users."
        else
          "Your staged rollout is *active*, and you are currently on stage *#{@current_stage} (#{@rollout_percentage}%)*."
        end
      end

      def secondary_text
        if @is_fully_released
          "View your release on the Play Console."
        else
          "You can choose to *Pause* or *Release to 100%*."
        end
      end
    end
  end
end
