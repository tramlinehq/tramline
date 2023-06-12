module Notifiers
  module Slack
    class Renderers::SubmitForReview < Renderers::Base
      TEMPLATE_FILE = "submit_for_review.json.erb".freeze
    end
  end
end
