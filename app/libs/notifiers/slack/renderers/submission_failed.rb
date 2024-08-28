module Notifiers
  module Slack
    class Renderers::SubmissionFailed < Renderers::Base
      TEMPLATE_FILE = "submission_failed.json.erb".freeze
    end
  end
end
