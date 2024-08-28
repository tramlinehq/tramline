module Notifiers
  module Slack
    class Renderers::BetaSubmissionFinished < Renderers::Base
      TEMPLATE_FILE = "beta_submission_finished.json.erb".freeze
    end
  end
end
