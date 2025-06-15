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

      def changelog_header
        if @continuation
          "…_#{@header_affix}_"
        else
          ":book: *#{@header_affix}*"
        end
      end
    end
  end
end
