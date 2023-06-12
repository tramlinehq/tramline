module Notifiers
  module Slack
    class Renderers::ReleaseStarted < Renderers::Base
      TEMPLATE_FILE = "release_started.json.erb".freeze
    end
  end
end
