module Notifiers
  module Slack
    class Renderers::BetaReleaseFailed < Renderers::Base
      TEMPLATE_FILE = "beta_release_failed.json.erb".freeze
    end
  end
end
