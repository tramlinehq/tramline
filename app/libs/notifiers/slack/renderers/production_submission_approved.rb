module Notifiers
  module Slack
    class Renderers::ProductionSubmissionApproved < Renderers::Base
      TEMPLATE_FILE = "production_submission_approved.json.erb".freeze
    end
  end
end
