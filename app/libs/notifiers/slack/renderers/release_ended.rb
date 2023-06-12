module Notifiers
  module Slack
    class Renderers::ReleaseEnded < Renderers::Base
      TEMPLATE_FILE = "release_ended.json.erb".freeze

      attr_accessor :final_artifact_url

      def initialize(**params)
        super(**params)
        @final_artifact = final_artifact
      end

      def final_artifact
        text = ""
        text += "\n*Download* the <#{@final_artifact_url}|final artifact>" if @final_artifact_url
        text
      end
    end
  end
end
