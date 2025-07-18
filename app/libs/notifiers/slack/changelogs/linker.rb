module Notifiers::Slack::Changelogs
  class Linker
    ISSUES_PATTERN = /\b([A-Z]+-\d+)\b/
    PR_PATTERN = /#(\d+)/

    def initialize(app)
      @app = app
      @vcs_provider = app.integrations.vcs_provider
      @project_management_provider = app.integrations.project_management_provider
    end

    def process(commit_message)
      return [] if commit_message.blank?

      @matchers = []
      match_issues(commit_message)
      match_pull_requests(commit_message)
      build_rich_text_elements(commit_message)
    end

    private

    def match_issues(message)
      return unless @project_management_provider&.respond_to?(:ticket_url)

      message.scan(ISSUES_PATTERN) do |match_array|
        match = Regexp.last_match
        next if match.blank? || match_array.empty?
        issue_id = match[1]

        @matchers << {
          start: match.begin(0),
          end: match.end(0),
          text: issue_id.to_s,
          url: @project_management_provider.ticket_url(issue_id)
        }
      end
    end

    def match_pull_requests(message)
      return unless @vcs_provider&.respond_to?(:pr_url)

      message.scan(PR_PATTERN) do |match_array|
        match = Regexp.last_match
        next if match.blank? || match_array.empty?
        pr_number = match[1]

        @matchers << {
          start: match.begin(0),
          end: match.end(0),
          text: "##{pr_number}", # Include the # symbol
          url: @vcs_provider.pr_url(pr_number)
        }
      end
    end

    def build_rich_text_elements(message)
      last_match_end = 0
      elements = []

      # sort matchers by position
      @matchers.sort_by! { |match| match[:start] }

      # process each matcher and add link elements
      @matchers.each do |match|
        if match[:start] > last_match_end
          text_before = message[last_match_end...match[:start]]
          elements << {"type" => "text", "text" => text_before} if text_before.present?
        end

        elements << {"type" => "link", "url" => match[:url], "text" => match[:text]}

        last_match_end = match[:end]
      end

      # add remaining text at the end if necessary
      if last_match_end < message.length
        remaining_text = message[last_match_end..]
        elements << {"type" => "text", "text" => remaining_text} if remaining_text.present?
      end

      elements
    end
  end
end
