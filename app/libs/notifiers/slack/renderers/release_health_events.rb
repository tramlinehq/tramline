module Notifiers
  module Slack
    class Renderers::ReleaseHealthEvents < Renderers::Base
      TEMPLATE_FILE = "release_health_events.json.erb".freeze

      def main_text
        return "The release is *unhealthy*! :broken_heart:" if @is_release_unhealthy
        "The release is *healthy*! :green_heart:"
      end

      def trigger_text(trigger)
        health_symbol = trigger[:is_healthy] ? ":large_green_circle:" : ":red_circle:"

        "#{health_symbol} #{trigger[:expression]}"
      end
    end
  end
end
