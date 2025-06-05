# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::Changelog < Renderers::Base
      TEMPLATE_FILE = "changelog.json.erb"

      def render_header
        {blocks: []}.to_json
      end

      def render_footer
        {blocks: []}.to_json
      end

      def changes_in_message(changes, &)
        changes[0...changes_limit].each_with_index do |change, i|
          yield change, i
        end
      end

      def changes_limit
        NotificationSetting::CHANGELOG_PER_MESSAGE_LIMIT
      end
    end
  end
end
