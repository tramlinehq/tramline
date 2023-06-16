module Notifiers
  module Slack
    class Renderers::StepFailed < Renderers::Base
      TEMPLATE_FILE = "step_failed.json.erb".freeze
    end
  end
end
