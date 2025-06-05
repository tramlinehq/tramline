# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::RcFinished < Renderers::Base
      TEMPLATE_FILE = "rc_finished.json.erb"

      def submission_text(submission)
        if submission.deep_link.present?
          ":white_check_mark: Submitted to <#{submission.deep_link}|*#{submission.display}*>"
        else
          ":white_check_mark: Submitted to *<#{submission.display}>"
        end
      end

      def changes_in_main_message(changes, &)
        changes[0, changes_limit].each_with_index do |change, i|
          yield change, i
        end
      end

      def changes_spillover?(changes)
        changes.size > changes_limit
      end

      def changes_limit
        NotificationSetting::CHANGELOG_PER_MESSAGE_LIMIT
      end
    end
  end
end
