module Notifiers
  module Slack
    class Renderers::ReleaseFinalizeFailed < Renderers::Base
      TEMPLATE_FILE = "release_finalize_failed.json.erb".freeze
    end
  end
end
