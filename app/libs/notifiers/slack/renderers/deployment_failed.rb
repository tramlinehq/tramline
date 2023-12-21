module Notifiers
  module Slack
    class Renderers::DeploymentFailed < Renderers::Base
      TEMPLATE_FILE = "deployment_failed.json.erb".freeze
    end
  end
end
