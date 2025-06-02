# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::Changelog < Renderers::Base
      TEMPLATE_FILE = "changelog.json.erb"

      delegate :changes_limit, :commit_truncate_length, to: :class

      class << self
        def changes_limit
          20
        end

        def commit_truncate_length
          70
        end
      end

      def render_header
        {blocks: []}.to_json
      end

      def render_footer
        {blocks: []}.to_json
      end
    end
  end
end
