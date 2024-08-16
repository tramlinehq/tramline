module Notifiers
  module Slack
    class Renderers::BuildAvailableV2 < Renderers::Base
      TEMPLATE_FILE = "build_available_v2.json.erb".freeze
    end
  end
end
