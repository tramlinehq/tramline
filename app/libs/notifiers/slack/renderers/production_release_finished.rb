module Notifiers
  module Slack
    class Renderers::ProductionReleaseFinished < Renderers::Base
      TEMPLATE_FILE = "production_release_finished.json.erb".freeze
    end
  end
end
