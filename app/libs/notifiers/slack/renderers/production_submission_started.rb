module Notifiers
  module Slack
    class Renderers::ProductionSubmissionStarted < Renderers::Base
      TEMPLATE_FILE = "production_submission_started.json.erb".freeze
    end
  end
end
