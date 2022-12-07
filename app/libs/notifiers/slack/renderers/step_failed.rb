module Notifiers
  module Slack
    class Renderers::StepFailed < Renderers::Base
      TEMPLATE_FILE = "step_failed.json.erb".freeze

      def initialize(**params)
        @reason = params[:reason]
        @step_run = params[:step_run]
        @step_name = @step_run.step.name
        @train_run = @step_run.train_run
        @train_name = @train_run.train.name
        @version_number = @step_run.build_version
        @release_page = release_page_link
        super
      end

      def release_page_link
        if Rails.env.development?
          release_url(@train_run, host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"])
        else
          release_url(@train_run, host: ENV["HOST_NAME"], protocol: "https")
        end
      end
    end
  end
end
