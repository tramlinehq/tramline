module Installations
  class Linear::Api
    include Vaultable
    attr_reader :oauth_access_token

    BASE_URL = "https://api.linear.app"
    GRAPHQL_URL = "#{BASE_URL}/graphql"
    DATA = Installations::Response::Keys

    class << self
      include Vaultable

      OAUTH_ACCESS_TOKEN_URL = "#{BASE_URL}/oauth/token"

      def get_access_token(code, redirect_uri)
        params = {
          form: {
            grant_type: :authorization_code,
            code:,
            redirect_uri:,
            client_id: creds.integrations.linear.client_id,
            client_secret: creds.integrations.linear.client_secret
          }
        }

        response = HTTP.post(OAUTH_ACCESS_TOKEN_URL, params)
        body = JSON.parse(response.body.to_s)

        tokens = {
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"]
        }

        return OpenStruct.new(tokens) if tokens.present?
        nil
      end

      def oauth_refresh_token(refresh_token, redirect_uri)
        params = {
          form: {
            grant_type: :refresh_token,
            redirect_uri:,
            refresh_token:,
            client_id: creds.integrations.linear.client_id,
            client_secret: creds.integrations.linear.client_secret
          }
        }

        response = HTTP.post(OAUTH_ACCESS_TOKEN_URL, params)
        body = JSON.parse(response.body.to_s)

        tokens = {
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"]
        }

        return OpenStruct.new(tokens) if tokens.present?
        nil
      end

      def get_organizations(access_token)
        query = {
          query: "query { organization { id name urlKey } }"
        }

        response = HTTP
          .auth("Bearer #{access_token}")
          .headers("Content-Type" => "application/json")
          .post(GRAPHQL_URL, json: query)

        return [] unless response.status.success?

        data = JSON.parse(response.body.to_s)
        [data.dig("data", "organization")].compact
      rescue HTTP::Error => e
        Rails.logger.error "Failed to fetch Linear organizations: #{e.message}"
        []
      end
    end

    def initialize(oauth_access_token)
      @oauth_access_token = oauth_access_token
    end

    def teams(transformations)
      query = {
        query: "query { teams { nodes { id key name description } } }"
      }

      response = execute_graphql(query)
      teams = response.dig("data", "teams", "nodes") || []
      DATA.transform(teams, transformations)
    end

    def workflow_states(transformations)
      query = {
        query: "query { workflowStates { nodes { id name type } } }"
      }

      response = execute_graphql(query)
      states = response.dig("data", "workflowStates", "nodes") || []
      DATA.transform(states, transformations).uniq { |state| state[:name] }
    end

    def search_issues_by_filters(team_id, release_filters, transformations)
      return {"issues" => []} if release_filters.blank?

      filter_conditions = build_filter_conditions(team_id, release_filters)

      query = {
        query: "query($filter: IssueFilter) { issues(filter: $filter) { nodes { id identifier title state { name } assignee { name } labels { nodes { name } } } } }",
        variables: {
          filter: filter_conditions
        }
      }

      response = execute_graphql(query)
      issues = response.dig("data", "issues", "nodes") || []
      {"issues" => DATA.transform(issues, transformations)}
    rescue HTTP::Error => e
      Rails.logger.error "Failed to search Linear issues: #{e.message}"
      raise Installations::Error.new("Failed to search Linear issues", reason: :api_error)
    end

    private

    def execute_graphql(query)
      response = HTTP
        .auth("Bearer #{oauth_access_token}")
        .headers("Content-Type" => "application/json")
        .post(GRAPHQL_URL, json: query)

      raise Installations::Error::ServerError if response.status.server_error?

      parsed_body = JSON.parse(response.body)
      Rails.logger.debug { "Linear API returned #{response.status} for GraphQL query with body - #{parsed_body}" }
      return parsed_body unless response.status.client_error?

      raise Installations::Error::TokenExpired if response.status == 401
      raise Installations::Error::ResourceNotFound if response.status == 404
      raise Installations::Linear::Error.new(parsed_body)
    end

    def build_filter_conditions(team_id, release_filters)
      conditions = {
        team: {id: {eq: team_id}}
      }

      release_filters.each do |filter|
        case filter["type"]
        when "label"
          conditions[:labels] = {name: {eq: filter["value"]}}
        when "state"
          conditions[:state] = {name: {eq: filter["value"]}}
        else
          Rails.logger.warn("Unsupported Linear filter type: #{filter["type"]}")
        end
      end

      conditions
    end
  end
end
