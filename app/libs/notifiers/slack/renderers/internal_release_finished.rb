module Notifiers
  module Slack
    class Renderers::InternalReleaseFinished < Renderers::Base
      TEMPLATE_FILE = "internal_release_finished.json.erb".freeze
    end
  end
end
