module Notifiers
  module Slack
    class Renderers::ReleaseStarted < Renderers::Base
      TEMPLATE_FILE = "release_started.json.erb".freeze

      def initialize(**params)
        @app_name = params[:app_name]
        @app_platform = params[:app_platform]
        @train_name = params[:train_name]
        @train_current_version = params[:train_current_version]
        @release_branch = params[:release_branch]
        @release_url = params[:release_url]
        @release_branch_url = params[:release_branch_url]
        super
      end
    end
  end
end
