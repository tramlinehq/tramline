# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::Changelog < Renderers::Base
      TEMPLATE_FILE = "changelog.json.erb"

      delegate :changes_limit, to: :class

      class << self
        def changes_limit
          20
        end
      end

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
    end
  end
end
