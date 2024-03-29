module Notifiers
  module Slack
    class Renderers::BuildAvailable < Renderers::Base
      TEMPLATE_FILE = "build_available.json.erb".freeze
    end
  end
end
