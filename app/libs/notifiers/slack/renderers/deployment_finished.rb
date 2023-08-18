module Notifiers
  module Slack
    class Renderers::DeploymentFinished < Renderers::Base
      include ActionView::Helpers::JavaScriptHelper

      TEMPLATE_FILE = "deployment_finished.json.erb".freeze

      def sanitized_build_notes
        escape_javascript("*Build notes*\n```#{@build_notes}```")
      end
    end
  end
end
