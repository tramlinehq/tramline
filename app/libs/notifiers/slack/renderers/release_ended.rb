module Notifiers
  module Slack
    class Renderers::ReleaseEnded < Renderers::Base
      TEMPLATE_FILE = "release_ended.json.erb".freeze
    end
  end
end
