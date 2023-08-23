module Notifiers
  module Slack
    class Renderers::SubmitForReview < Renderers::Base
      TEMPLATE_FILE = "submit_for_review.json.erb".freeze

      def initialize(**params)
        super(**params)
        @publishing_text = publishing_text
        @company_text = company_text
        @store_text = store_text
      end

      def sanitized_release_notes
        safe_string(":spiral_note_pad: What's New\n\n```#{@release_notes}```")
      end

      def publishing_text
        if @is_play_store_production
          "managed publishing"
        elsif @is_app_store_production
          "manual publishing"
        end
      end

      def company_text
        if @is_play_store_production
          "Google"
        elsif @is_app_store_production
          "Apple"
        end
      end

      def store_text
        if @is_play_store_production
          "Play Store"
        elsif @is_app_store_production
          "App Store"
        end
      end
    end
  end
end
