module Notifiers
  module Slack
    class Renderers::WorkflowRunHalted < Renderers::Base
      TEMPLATE_FILE = "workflow_run_halted.json.erb".freeze
    end
  end
end
