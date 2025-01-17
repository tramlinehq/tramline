module Installations
  class Jira::Api
    include Vaultable
    attr_reader :oauth_access_token, :cloud_id

    BASE_URL = "https://api.atlassian.com/ex/jira"

    # API Endpoints
    PROJECTS_URL = Addressable::Template.new "#{BASE_URL}/{cloud_id}/rest/api/3/project/search"
    PROJECT_STATUSES_URL = Addressable::Template.new "#{BASE_URL}/{cloud_id}/rest/api/3/project/{project_key}/statuses"
    SEARCH_URL = Addressable::Template.new "#{BASE_URL}/{cloud_id}/rest/api/3/search/jql"
    TICKET_SEARCH_FIELDS = "summary, description, status, assignee, fix_versions, labels"

    class << self
      include Vaultable

      OAUTH_ACCESS_TOKEN_URL = "https://auth.atlassian.com/oauth/token"
      ACCESSIBLE_RESOURCES_URL = "https://api.atlassian.com/oauth/token/accessible-resources"

      def get_accessible_resources(code, redirect_uri)
        @tokens ||= oauth_access_token(code, redirect_uri)
        return [[], @tokens] unless @tokens

        response = HTTP
          .auth("Bearer #{@tokens.access_token}")
          .get(ACCESSIBLE_RESOURCES_URL)

        return [[], @tokens] unless response.status.success?
        [JSON.parse(response.body.to_s), @tokens]
      rescue HTTP::Error => e
        Rails.logger.error "Failed to fetch Jira accessible resources: #{e.message}"
        [[], @tokens]
      end

      def oauth_access_token(code, redirect_uri)
        params = {
          form: {
            grant_type: :authorization_code,
            code:,
            redirect_uri:
          }
        }

        get_oauth_token(params)
      end

      def oauth_refresh_token(refresh_token, redirect_uri)
        params = {
          form: {
            grant_type: :refresh_token,
            redirect_uri:,
            refresh_token:
          }
        }

        get_oauth_token(params)
      end

      def get_oauth_token(params)
        response = HTTP
          .basic_auth(user: creds.integrations.jira.client_id, pass: creds.integrations.jira.client_secret)
          .post(OAUTH_ACCESS_TOKEN_URL, params)

        body = JSON.parse(response.body.to_s)
        tokens = {
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"]
        }

        return OpenStruct.new(tokens) if tokens.present?
        nil
      end
    end

    def initialize(oauth_access_token, cloud_id)
      @oauth_access_token = oauth_access_token
      @cloud_id = cloud_id
    end

    def projects(transformations)
      response = execute(:get, PROJECTS_URL.expand(cloud_id:).to_s)
      transform_data(response["values"], transformations)
    end

    def project_statuses(project_key, transformations)
      response = execute(:get, PROJECT_STATUSES_URL.expand(cloud_id:, project_key:).to_s)
      extract_unique_statuses(response, transformations)
    end

    def search_tickets_by_filters(project_key, release_filters, transformations, start_at: 0, max_results: 50)
      return {"issues" => []} if release_filters.blank?
      params = {
        params: {
          jql: build_jql_query(project_key, release_filters),
          fields: TICKET_SEARCH_FIELDS
        }
      }

      response = execute(:get, SEARCH_URL.expand(cloud_id:).to_s, params)
      transform_data(response["issues"], transformations)
    rescue HTTP::Error => e
      Rails.logger.error "Failed to search Jira tickets: #{e.message}"
      raise Installations::Error.new("Failed to search Jira tickets", reason: :api_error)
    end

    private

    def extract_unique_statuses(statuses, transformations)
      statuses.flat_map { |issue_type| issue_type["statuses"] }
        .uniq { |status| status["id"] }
        .then { |statuses| transform_data(statuses, transformations) }
    end

    def transform_data(data, transformations)
      Installations::Response::Keys.transform(data, transformations)
    end

    def execute(method, url, params = {}, parse_response = true)
      response = HTTP.auth("Bearer #{oauth_access_token}").headers("Accept" => "application/json").public_send(method, url, params)

      parsed_body = parse_response ? JSON.parse(response.body) : response.body
      Rails.logger.debug { "Jira API returned #{response.status} for #{url} with body - #{parsed_body}" }

      return parsed_body unless response.status.client_error?

      raise Installations::Error.new("Token expired", reason: :token_expired) if response.status == 401
      raise Installations::Error.new("Resource not found", reason: :not_found) if response.status == 404
      raise Installations::Jira::Error.new(parsed_body)
    end

    def build_jql_query(project_key, release_filters)
      conditions = ["project = '#{sanitize_jql_value(project_key)}'"]
      release_filters.each do |filter|
        value = sanitize_jql_value(filter["value"])
        filter_condition =
          case filter["type"]
          when "label" then "labels = '#{value}'"
          when "fix_version" then "fixVersion = '#{value}'"
          else Rails.logger.warn("Unsupported Jira filter type: #{filter["type"]}")
          end
        conditions << filter_condition if filter_condition
      end
      conditions.join(" AND ")
    end

    def sanitize_jql_value(value)
      value.to_s.gsub("'", "\\'").gsub(/[^\w\s\-\.]/, "")
    end
  end
end
