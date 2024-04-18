module Notifiers
  module Slack
    class Renderers::ReleaseHealthEvents < Renderers::Base
      TEMPLATE_FILE = "release_health_events.json.erb".freeze

      def main_text
        return "The release is *unhealthy*! :broken_heart:" if @is_release_unhealthy
        "The release is *healthy*! :green_heart:"
      end

      def trigger_text
        safe_string(@release_health_rule_triggers.map do |trigger|
          health_symbol = trigger[:is_healthy] ? ":large_green_circle:" : ":red_circle:"
          "#{health_symbol} #{trigger[:expression]}"
        end.join("\n "))
      end

      def filter_text
        safe_string(@release_health_rule_filters.map { |filter| ":clock5: #{filter}" }.join("\n "))
      end
    end
  end
end
