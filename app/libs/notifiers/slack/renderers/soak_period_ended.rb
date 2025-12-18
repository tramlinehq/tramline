module Notifiers
  module Slack
    class Renderers::SoakPeriodEnded < Renderers::Base
      include ApplicationHelper
      include ActionView::Helpers::DateHelper

      TEMPLATE_FILE = "soak_period_ended.json.erb".freeze

      def ended_at
        time_format(@beta_soak_ended_at, with_tz: true)
      end
    end
  end
end
