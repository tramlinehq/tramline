module Notifiers
  module Slack
    class Renderers::WorkflowTriggerFailed < Renderers::Base
      TEMPLATE_FILE = "workflow_trigger_failed.json.erb".freeze
    end
  end
end
