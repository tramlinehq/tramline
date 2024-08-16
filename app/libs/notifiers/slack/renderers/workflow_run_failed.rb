module Notifiers
  module Slack
    class Renderers::WorkflowRunFailed < Renderers::Base
      TEMPLATE_FILE = "workflow_run_failed.json.erb".freeze
    end
  end
end
