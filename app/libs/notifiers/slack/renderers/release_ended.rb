module Notifiers
  module Slack
    class Renderers::ReleaseEnded < Renderers::Base
      TEMPLATE_FILE = "release_ended.json.erb".freeze

      def initialize(**params)
        @total_run_time = params[:total_run_time]
        @release_tag = params[:release_tag]
        @release_tag_url = params[:release_tag_url]
        @final_artifact_url = params[:final_artifact_url]
        @store_url = params[:store_url]
        @main_text = main_text
        super
      end

      def main_text
        text = <<~MARKDOWN.strip
          *Total Run Time:* #{@total_run_time}
          *Release Tag:* <#{@release_tag_url}|#{@release_tag}>
          *Store Link:* #{@store_url}
        MARKDOWN
        text += "\n*Final Artifact:* <#{@final_artifact_url}|Download>" if @final_artifact_url
        text
      end
    end
  end
end
