module Notifiers
  module Slack
    class Renderers::LifecycleHookFailed < Renderers::Base
      TEMPLATE_FILE = "lifecycle_hook_failed.json.erb".freeze
    end
  end
end
