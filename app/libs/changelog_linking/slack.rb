module ChangelogLinking
  class Slack < Base
    private

    def format_message(message)
      "• #{message}"
    end

    def format_ticket_link(url, ticket_id)
      "<#{url}%7C#{ticket_id}>"
    end

    def format_pr_link(url, pr_text)
      "<#{url}%7C#{pr_text}>"
    end
  end
end
