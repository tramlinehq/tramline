module Notifiers
  module Slack
    class Renderers::SoakPeriodStarted < Renderers::Base
      include ApplicationHelper
      include ActionView::Helpers::DateHelper

      TEMPLATE_FILE = "soak_period_started.json.erb".freeze

      def started_at
        time_format(@beta_soak_started_at, with_tz: true)
      end

      def time_remaining
        duration_in_words(@beta_soak_time_remaining)
      end
    end
  end
end
