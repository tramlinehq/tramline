module Notifiers
  module Slack
    class Renderers::ReleaseScheduled < Renderers::Base
      TEMPLATE_FILE = "release_scheduled.json.erb".freeze
    end
  end
end
