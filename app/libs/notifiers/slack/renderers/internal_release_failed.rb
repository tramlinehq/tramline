module Notifiers
  module Slack
    class Renderers::InternalReleaseFailed < Renderers::Base
      TEMPLATE_FILE = "internal_release_failed.json.erb".freeze
    end
  end
end
