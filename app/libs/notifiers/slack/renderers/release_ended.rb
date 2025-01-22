module Notifiers
  module Slack
    class Renderers::ReleaseEnded < Renderers::Base
      include ActionView::Helpers::DateHelper

      TEMPLATE_FILE = "release_ended.json.erb".freeze

      def total_run_time
        return "N/A" if @release_completed_at.blank? || @release_started_at.blank?
        distance_of_time_in_words(@release_started_at, @release_completed_at)
      end

      def cross_platform?
        @app_platform == App.platforms[:cross_platform]
      end

      def android_finished_text
        if @final_android_release_version.present?
          ":white_check_mark: The Android release finished with the final version of *#{@final_android_release_version}*"
        else
          ":large_yellow_circle: The Android release did not finish"
        end
      end

      def ios_finished_text
        if @final_ios_release_version.present?
          ":white_check_mark: The iOS release finished with the final version of *#{@final_ios_release_version}*"
        else
          ":large_yellow_circle: The iOS release did not finish"
        end
      end
    end
  end
end
