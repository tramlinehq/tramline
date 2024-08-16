module Notifiers
  module Slack
    class Renderers::BetaSubmissionFailed < Renderers::Base
      TEMPLATE_FILE = "beta_submission_failed.json.erb".freeze
    end
  end
end
