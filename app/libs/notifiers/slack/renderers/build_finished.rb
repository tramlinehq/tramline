module Notifiers
  module Slack
    class Renderers::BuildFinished < Renderers::Base
      TEMPLATE_FILE = "build_finished.json.erb".freeze

      def initialize(**params)
        @code_name = params[:code_name]
        @branch_name = params[:branch_name]
        @build_number = params[:build_number]
        @artifacts_url = params[:artifacts_url]
        @version_number = params[:version_number]
        super
      end
    end
  end
end
