module Notifiers
  module Slack
    class Renderers::ProductionRolloutHalted < Renderers::Base
      TEMPLATE_FILE = "production_rollout_halted.json.erb".freeze
    end
  end
end
