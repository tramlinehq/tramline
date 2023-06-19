module Notifiers
  module Slack
    class Renderers::ReleaseStopped < Renderers::Base
      TEMPLATE_FILE = "release_stopped.json.erb".freeze
    end
  end
end
