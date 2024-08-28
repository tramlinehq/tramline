module Notifiers
  module Slack
    class Renderers::ProductionRolloutPaused < Renderers::Base
      TEMPLATE_FILE = "production_rollout_paused.json.erb".freeze
    end
  end
end
