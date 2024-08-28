module Notifiers
  module Slack
    class Renderers::ProductionSubmissionRejected < Renderers::Base
      TEMPLATE_FILE = "production_submission_rejected.json.erb".freeze
    end
  end
end
