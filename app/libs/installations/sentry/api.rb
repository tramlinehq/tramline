module Installations
  class Sentry::Api
    include Loggable
    attr_reader :access_token, :base_url

    def initialize(access_token)
      @access_token = access_token
      @base_url = "https://sentry.io/api/0"
    end

    def list_organizations(transforms)
      execute do
        organizations = paginated_execute("/organizations/", max_results: 200)
        return nil if organizations.blank?
        Installations::Response::Keys.transform(organizations, transforms)
      end
    end

    def list_projects(org_slug, transforms)
      execute do
        projects = paginated_execute("/organizations/#{org_slug}/projects/", max_results: 500)
        return nil if projects.blank?

        # Attach organization slug to each project for easier lookup
        projects_with_org = projects.map { |project| project.merge("organization_slug" => org_slug) }
        Installations::Response::Keys.transform(projects_with_org, transforms)
      end
    end

    def find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)
      execute do
        # Construct Sentry release identifier: <bundle_id>@<version>+<build_number>
        # Format documented at:
        # iOS: https://docs.sentry.io/platforms/apple/guides/ios/configuration/releases/#bind-the-version
        # Android: https://docs.sentry.io/platforms/android/configuration/releases/#bind-the-version
        version_string = "#{bundle_identifier}@#{app_version}+#{app_version_code}"

        # Fetch all data in parallel for efficiency
        stats_thread = fetch_release_stats_async(org_slug, project_id, environment, version_string)
        all_issues_thread = fetch_all_issues_async(org_slug, project_slug, version_string)
        new_issues_thread = fetch_new_issues_async(org_slug, project_slug, version_string)

        # Wait for all threads to complete
        stats = stats_thread.value
        all_issues = all_issues_thread.value || []
        new_issues = new_issues_thread.value || []

        return nil if stats.blank? || stats["groups"].blank?

        # Build issue counts
        issues_data = {
          total_issues_count: all_issues.size,
          new_issues_count: new_issues.size
        }

        # Transform stats to match expected format
        release_data = build_release_data(stats, version_string, issues_data)
        Installations::Response::Keys.transform([release_data], transforms).first
      end
    end

    private

    def fetch_release_stats_async(org_slug, project_id, environment, version)
      # Calculate time window using configured monitoring period
      end_time = Time.current
      start_time = end_time - ProductionRelease::RELEASE_MONITORING_PERIOD_IN_DAYS[SentryIntegration].days

      # Build query parameters for session statistics
      params = {
        project: project_id,
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

      get_request_async("/organizations/#{org_slug}/sessions/", params)
    end

    def fetch_all_issues_async(org_slug, project_slug, version)
      get_request_async(
        "/projects/#{org_slug}/#{project_slug}/issues/",
        {query: "release:#{version}"}
      )
    end

    def fetch_new_issues_async(org_slug, project_slug, version)
      get_request_async(
        "/projects/#{org_slug}/#{project_slug}/issues/",
        {query: "firstRelease:#{version}"}
      )
    end

    def build_release_data(stats, version, issues_data = {})
      # Parse session statistics from Sentry response
      groups = stats["groups"] || []

      # Sum up totals across all groups
      total_sessions = 0
      total_users = 0
      errored_sessions = 0
      users_with_errors = 0

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
          errored_sessions += sessions # crashed sessions are also errored
          users_with_errors += users
        end
      end

      {
        version: version,
        total_sessions_count: total_sessions,
        errored_sessions_count: errored_sessions,
        total_users_count: total_users,
        users_with_errors_count: users_with_errors,
        new_issues_count: issues_data[:new_issues_count] || 0,
        total_issues_count: issues_data[:total_issues_count] || 0
      }
    end

    def get_request(path, params = {})
      url = "#{base_url}#{path}"
      response = HTTP
        .auth("Bearer #{access_token}")
        .timeout(connect: 10, read: 30)
        .get(url, params: params)

      if response.status.success?
        JSON.parse(response.body.to_s)
      else
        elog("Sentry API error: #{response.code} - #{response.body}", level: :warn)
        nil
      end
    end

    def get_request_async(path, params = {})
      Thread.new { get_request(path, params) }
    end

    def paginated_execute(path, params: {}, values: [], cursor: nil, max_results: nil)
      # Build full URL with cursor if present
      url = "#{base_url}#{path}"
      params = params.merge(cursor: cursor) if cursor.present?

      response = HTTP
        .auth("Bearer #{access_token}")
        .timeout(connect: 10, read: 30)
        .get(url, params: params)

      return values unless response.status.success?

      # Parse and accumulate results
      page_data = JSON.parse(response.body.to_s)
      values.concat(page_data) if page_data.is_a?(Array)

      # Check if we've reached max_results limit
      return values if max_results && values.length >= max_results

      # Parse Link header for next cursor
      # Format: <https://sentry.io/api/0/path?cursor=xyz>; rel="next"
      link_header = response.headers["Link"]
      return values if link_header.blank?

      next_cursor = extract_next_cursor(link_header)
      return values if next_cursor.blank?

      # Recursive call with next cursor
      paginated_execute(path, params: params.except(:cursor), values: values, cursor: next_cursor, max_results: max_results)
    end

    def extract_next_cursor(link_header)
      # Parse Link header for rel="next" and extract cursor parameter
      next_match = link_header.match(/<([^>]+)>;\s*rel="next"/)
      return nil unless next_match

      next_uri = URI.parse(next_match[1])
      query_params = URI.decode_www_form(next_uri.query || "").to_h
      query_params["cursor"]
    end

    def execute
      yield
    rescue => e
      elog(e, level: :warn)
      nil
    end
  end
end
