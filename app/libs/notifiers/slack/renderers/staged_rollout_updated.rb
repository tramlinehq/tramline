module Notifiers
  module Slack
    class Renderers::StagedRolloutUpdated < Renderers::Base
      TEMPLATE_FILE = "staged_rollout_updated.json.erb".freeze
    end
  end
end
