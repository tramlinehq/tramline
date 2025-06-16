module Notifiers
  module Slack
    class Renderers::InternalReleaseFinished < Renderers::Base
      TEMPLATE_FILE = "internal_release_finished.json.erb".freeze

      def main_text
        text = ":sparkles: The internal build step finished for *#{@release_version} (#{@build_number})* for commit <#{@commit_url}|#{@commit_sha}>."
        text += " The build has been sent to #{submission_channels}." if submission_channels.present?
        text
      end

      def submission_channels
        @submissions.map { |s| "#{s.provider.display} - #{s.submission_channel.name}" }.join(", ")
      end
    end
  end
end
