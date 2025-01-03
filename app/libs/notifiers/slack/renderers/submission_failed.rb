module Notifiers
  module Slack
    class Renderers::SubmissionFailed < Renderers::Base
      TEMPLATE_FILE = "submission_failed.json.erb".freeze

      def submission_failure_text
        text = ":octagonal_sign: The submission to *#{@submission_channel}* failed for *#{@release_version} (#{@build_number})* for <#{@commit_url}|#{@commit_sha}>"
        text += " and requires a manual intervention" if @submission_requires_manual_action
        text += ". Please check the release page for more details. \n\n *Error* \n ```#{@submission_failure_reason}```"
        text
      end
    end
  end
end
