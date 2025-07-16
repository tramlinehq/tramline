module ChangelogLinking
  class Base
    TICKET_PATTERN = /\b([A-Z]+-\d+)\b/
    PR_PATTERN = /#(\d+)/

    def initialize(app)
      @app = app
      @project_management_provider = app.integrations.project_management_provider
      @vcs_provider = app.integrations.vcs_provider
    end

    def process(commit_messages)
      return [] if commit_messages.blank?
      commit_messages.map { |message| process_single_message(message) }
    end

    private

    def process_single_message(message)
      processed = message.dup
      processed = process_ticket_links(processed)
      processed = process_pr_links(processed)
      format_message(processed)
    end

    def process_ticket_links(message)
      return message unless @project_management_provider&.respond_to?(:ticket_url)

      message.gsub(TICKET_PATTERN) do |match|
        ticket_id = $1
        ticket_url = @project_management_provider.ticket_url(ticket_id)
        format_ticket_link(ticket_url, ticket_id)
      end
    end

    def process_pr_links(message)
      return message unless @vcs_provider&.respond_to?(:pr_url)

      message.gsub(PR_PATTERN) do |match|
        pr_number = $1
        pr_url = @vcs_provider.pr_url(pr_number)
        format_pr_link(pr_url, match)
      end
    end

    def format_message(message)
      raise NotImplementedError, "Subclasses must implement format_message"
    end

    def format_ticket_link(url, ticket_id)
      raise NotImplementedError, "Subclasses must implement format_ticket_link"
    end

    def format_pr_link(url, pr_text)
      raise NotImplementedError, "Subclasses must implement format_pr_link"
    end
  end
end
