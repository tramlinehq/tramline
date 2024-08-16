module Notifiers
  module Slack
    class Renderers::ProductionSubmissionFailed < Renderers::Base
      TEMPLATE_FILE = "production_submission_failed.json.erb".freeze
    end
  end
end
