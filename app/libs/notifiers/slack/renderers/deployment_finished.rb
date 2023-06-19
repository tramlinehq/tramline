module Notifiers
  module Slack
    class Renderers::DeploymentFinished < Renderers::Base
      TEMPLATE_FILE = "deployment_finished.json.erb".freeze
    end
  end
end
