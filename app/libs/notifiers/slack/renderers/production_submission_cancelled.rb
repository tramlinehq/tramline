module Notifiers
  module Slack
    class Renderers::ProductionSubmissionCancelled < Renderers::Base
      TEMPLATE_FILE = "production_submission_cancelled.json.erb".freeze
    end
  end
end
