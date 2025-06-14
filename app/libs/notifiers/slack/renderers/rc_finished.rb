# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::RcFinished < Renderers::Base
      TEMPLATE_FILE = "rc_finished.json.erb"

      def submission_text(submission)
        if submission.deep_link.present?
          ":white_check_mark: Submitted to <#{submission.deep_link}|*#{submission.display}*>"
        else
          ":white_check_mark: Submitted to *#{submission.display}*"
        end
      end
    end
  end
end
