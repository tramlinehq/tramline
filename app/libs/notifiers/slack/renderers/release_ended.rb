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
        super
      end
    end
  end
end
