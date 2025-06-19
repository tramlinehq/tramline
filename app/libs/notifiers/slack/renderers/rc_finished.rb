# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::RcFinished < Renderers::Base
      TEMPLATE_FILE = "rc_finished.json.erb"

      def submission_text(sub)
        if sub.deep_link.present?
          ":white_check_mark: Submitted to <#{sub.deep_link}|*#{sub.display}* (#{sub.submission_channel.name})>"
        else
          ":white_check_mark: Submitted to *#{sub.display}* (#{sub.submission_channel.name})"
        end
      end

      def changelog_header
        ":memo: *#{@changelog[:header_affix]}*"
      end
    end
  end
end
