module Notifiers
  module Slack
    class Renderers::BackmergeFailed < Renderers::Base
      TEMPLATE_FILE = "backmerge_failed.json.erb".freeze

      def failure_text
        ":exclamation: Automatic backmerge failed for <#{@commit_url}|#{@commit_sha}> due to a merge conflict."
      end

      def sanitized_commit_message
        safe_string("```#{@commit_message}```")
      end

      def action_text
        "#{@commit_author} needs to merge this change to the working branch `#{working_branch}` manually."
      end
    end
  end
end
