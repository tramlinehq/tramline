module Notifiers
  module Slack
    class Renderers::StepStarted < Renderers::Base
      TEMPLATE_FILE = "step_started.json.erb".freeze
    end
  end
end
