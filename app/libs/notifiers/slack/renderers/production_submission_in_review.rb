module Notifiers
  module Slack
    class Renderers::ProductionSubmissionInReview < Renderers::Base
      TEMPLATE_FILE = "production_submission_in_review.json.erb".freeze
    end
  end
end
