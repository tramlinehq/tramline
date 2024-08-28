module Notifiers
  module Slack
    class Renderers::WorkflowRunUnavailable < Renderers::Base
      TEMPLATE_FILE = "workflow_run_unavailable.json.erb".freeze
    end
  end
end
