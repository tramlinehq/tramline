module Installations
  require "net/http"
  require "json"

  class Sentry::Api
    include Loggable
    attr_reader :access_token, :base_url

    def initialize(access_token)
      @access_token = access_token
      @base_url = "https://sentry.io/api/0"
    end

    def list_organizations(transforms)
      execute do
        organizations = get_request("/organizations/")
        Installations::Response::Keys.transform(organizations, transforms)
      end
    end

    def list_projects(org_slug, transforms)
      execute do
        projects = get_request("/organizations/#{org_slug}/projects/")
        Installations::Response::Keys.transform(projects, transforms)
      end
    end

    def find_release(org_slug, project_slug, environment, app_version, app_version_code, transforms)
      execute do
        # Construct version string: version-buildnumber
        version_string = "#{app_version}-#{app_version_code}"

        # Fetch session stats for this release
        stats = fetch_release_stats(org_slug, project_slug, environment, version_string)
        return nil if stats.blank?

        # Transform stats to match expected format
        release_data = build_release_data(stats, version_string)
        Installations::Response::Keys.transform([release_data], transforms).first
      end
    end

    private

    def fetch_release_stats(org_slug, project_slug, environment, version)
      # Calculate time window - last 7 days
      end_time = Time.current
      start_time = end_time - 7.days

      # Build query parameters for session statistics
      params = {
        project: project_slug,
        field: [
          "sum(session)",
          "count_unique(user)",
          "crash_free_rate(session)",
          "crash_free_rate(user)"
        ],
        groupBy: ["release", "session.status"],
        environment: environment,
        query: "release:#{version}",
        start: start_time.utc.iso8601,
        end: end_time.utc.iso8601,
        interval: "1d"
      }

      response = get_request("/organizations/#{org_slug}/sessions/", params)
      response
    end

    def build_release_data(stats, version)
      # Parse session statistics from Sentry response
      groups = stats["groups"] || []

      # Sum up totals across all groups
      total_sessions = 0
      total_users = 0
      errored_sessions = 0
      users_with_errors = 0
      crashed_sessions = 0

      groups.each do |group|
        totals = group["totals"] || {}
        session_status = group.dig("by", "session.status")

        sessions = totals["sum(session)"] || 0
        users = totals["count_unique(user)"] || 0

        total_sessions += sessions
        total_users += users

        # Track errored and crashed sessions
        if session_status == "errored"
          errored_sessions += sessions
          users_with_errors += users
        elsif session_status == "crashed"
          crashed_sessions += sessions
          errored_sessions += sessions # crashed sessions are also errored
          users_with_errors += users
        end
      end

      # Calculate stability rates
      # Sentry provides crash_free_rate, we need to calculate stability
      session_stability = total_sessions > 0 ? ((total_sessions - errored_sessions).to_f / total_sessions * 100) : 100
      user_stability = total_users > 0 ? ((total_users - users_with_errors).to_f / total_users * 100) : 100

      {
        version: version,
        total_sessions_count: total_sessions,
        errored_sessions_count: errored_sessions,
        total_users_count: total_users,
        users_with_errors_count: users_with_errors,
        # Note: Sentry doesn't provide "new issues" in session stats
        # This would require a separate issues API call
        new_issues_count: 0,
        total_issues_count: 0
      }
    end

    def get_request(path, params = {})
      uri = URI("#{base_url}#{path}")
      uri.query = URI.encode_www_form(flatten_params(params)) unless params.empty?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      else
        elog("Sentry API error: #{response.code} - #{response.body}", level: :warn)
        nil
      end
    end

    # Flatten array parameters for URL encoding
    # e.g., {field: ["a", "b"]} => [["field", "a"], ["field", "b"]]
    def flatten_params(params)
      params.flat_map do |key, value|
        if value.is_a?(Array)
          value.map { |v| [key, v] }
        else
          [[key, value]]
        end
      end
    end

    def execute
      yield
    rescue => e
      elog(e, level: :warn)
      nil
    end
  end
end
