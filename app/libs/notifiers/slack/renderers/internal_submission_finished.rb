module Notifiers
  module Slack
    class Renderers::InternalSubmissionFinished < Renderers::Base
      TEMPLATE_FILE = "internal_submission_finished.json.erb".freeze
    end
  end
end
