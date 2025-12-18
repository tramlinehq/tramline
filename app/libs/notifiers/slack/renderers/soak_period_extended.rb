module Notifiers
  module Slack
    class Renderers::SoakPeriodExtended < Renderers::Base
      include ApplicationHelper
      include ActionView::Helpers::DateHelper

      TEMPLATE_FILE = "soak_period_extended.json.erb".freeze

      def time_remaining
        duration_in_words(@beta_soak_time_remaining)
      end
    end
  end
end
