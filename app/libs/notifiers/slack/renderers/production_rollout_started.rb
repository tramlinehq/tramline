module Notifiers
  module Slack
    class Renderers::ProductionRolloutStarted < Renderers::Base
      TEMPLATE_FILE = "production_rollout_started.json.erb".freeze
    end
  end
end
