module Notifiers
  module Slack
    class Renderers::ReleaseStarted < Renderers::Base
      TEMPLATE_FILE = "release_started.json.erb".freeze

      def initialize(**params)
        @train_name = params[:train_name]
        @commit_msg = params[:commit_msg]
        @branch_name = params[:branch_name]
        @version_number = params[:version_number]
        super
      end
    end
  end
end
