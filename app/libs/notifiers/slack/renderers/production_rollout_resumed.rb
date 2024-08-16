module Notifiers
  module Slack
    class Renderers::ProductionRolloutResumed < Renderers::Base
      TEMPLATE_FILE = "production_rollout_resumed.json.erb".freeze
    end
  end
end
