module Notifiers
  module Slack
    class Renderers::ProductionRolloutUpdated < Renderers::Base
      TEMPLATE_FILE = "production_rollout_updated.json.erb".freeze
    end
  end
end
