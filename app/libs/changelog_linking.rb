module ChangelogLinking
  class Processor
    TICKET_PATTERN = /\b([A-Z]+-\d+)\b/
    PR_PATTERN = /#(\d+)/
    MAX_CHUNK_SIZE = 3500

    def initialize(app)
      @app = app
      @project_management_provider = app.integrations.project_management_provider
      @vcs_provider = app.integrations.vcs_provider
    end

    def process(commit_messages)
      return ["[]"] if commit_messages.blank?

      linked_messages = commit_messages.map { |message| process_single_message(message) }
      grouped_messages = group_by_ticket_prefix(linked_messages)
      split_into_chunks(grouped_messages)
    end

    private

    def process_single_message(message)
      processed = message.dup

      processed = process_ticket_links(processed)
      processed = process_pr_links(processed)

      "• #{processed}"
    end

    def process_ticket_links(message)
      return message unless @project_management_provider

      message.gsub(TICKET_PATTERN) do |match|
        ticket_id = $1
        case @project_management_provider.class.name
        when "LinearIntegration"
          "<https://linear.app/dummy/issue/#{ticket_id}%7C#{ticket_id}>"
        when "JiraIntegration"
          cloud_id = @project_management_provider.cloud_id
          "<https://#{cloud_id}.atlassian.net/browse/#{ticket_id}%7C#{ticket_id}>"
        else
          match
        end
      end
    end

    def process_pr_links(message)
      return message unless @vcs_provider

      message.gsub(PR_PATTERN) do |match|
        pr_number = $1
        pr_url = build_pr_url(pr_number)
        "<#{pr_url}%7C#{match}>"
      end
    end

    def build_pr_url(pr_number)
      case @vcs_provider.class.name
      when "GithubIntegration"
        "https://github.com/tramlinehq/ueno/pull/#{pr_number}"
      when "GitlabIntegration"
        "https://gitlab.com/#{@vcs_provider.code_repository_name}/-/merge_requests/#{pr_number}"
      when "BitbucketIntegration"
        "https://bitbucket.org/#{@vcs_provider.code_repository_name}/pull-requests/#{pr_number}"
      else
        "##{pr_number}"
      end
    end

    def group_by_ticket_prefix(messages)
      groups = {}
      general_items = []

      messages.each do |message|
        ticket_match = message.match(TICKET_PATTERN)
        if ticket_match
          prefix = ticket_match[1].split("-").first
          groups[prefix] ||= []
          groups[prefix] << message
        else
          general_items << message
        end
      end

      result = []

      if general_items.any?
        result << "General"
        result.concat(general_items)
        result << ""
      end

      groups.keys.sort.each do |prefix|
        result << prefix
        result.concat(groups[prefix])
        result << ""
      end

      result.pop if result.last == ""

      result
    end

    def split_into_chunks(grouped_messages)
      return ["[]"] if grouped_messages.empty?

      chunks = []
      current_chunk = []
      current_size = 0

      grouped_messages.each do |line|
        # Account for JSON encoding overhead (quotes, escaping, etc.)
        line_json_size = line.to_json.length + 1
        
        if current_size + line_json_size > MAX_CHUNK_SIZE && current_chunk.any?
          chunks << current_chunk.join("\n")
          current_chunk = [line]
          current_size = line_json_size
        else
          current_chunk << line
          current_size += line_json_size
        end
      end

      chunks << current_chunk.join("\n") if current_chunk.any?
      
      chunks.map { |chunk| chunk.to_json }
    end
  end
end
