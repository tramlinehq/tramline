require "google/cloud/bigquery"
require "json"
require_relative "error"

module Installations
  class Crashlytics::Api
    include Loggable

    BIGQUERY = ::Google::Cloud::Bigquery

    attr_reader :json_key, :project_number

    def initialize(project_number, json_key)
      @project_number = project_number
      @json_key = json_key
    end

    def find_release(app_id, app_version, app_version_code, transforms)
      execute do
        crash_data = fetch_crash_data(app_id, app_version)
        return if crash_data.blank?
        # Ensure all required keys are included
        crash_data = ensure_required_keys(crash_data, transforms)
        # Transform the data with the specified transformations
        Installations::Response::Keys.transform([crash_data], transforms).first
      end
    end

    def list_apps(transforms)
      execute { firebase_management_service.list_apps(transforms) }
    end

    private

    # Fetch and merge analytics and crashlytics data
    def fetch_crash_data(app_id, app_version)
      analytics = release_data(app_id)[:analytics_data].find { |a| a[:version_name] == app_version } || {}
      crashlytics = release_data(app_id)[:crashlytics_data].find { |c| c[:version_name] == app_version } || {}
      analytics.merge(crashlytics)
    end

    # Ensure required keys are present in the crash data
    def ensure_required_keys(crash_data, transforms)
      transforms.each do |old_key, new_key|
        crash_data[new_key] ||= crash_data[old_key] if crash_data.has_key?(old_key)
      end
      crash_data
    end

    # Memoized BigQuery client
    def bigquery_client
      @bigquery_client ||= BIGQUERY.new(credentials: key_file)
    end

    # Query dataset names and return relevant datasets
    def datasets
      execute do
        target_datasets = {}
        bigquery_client.datasets.each do |dataset|
          case dataset.dataset_id
          when /^analytics_\d+$/ then target_datasets[:ga4] = dataset_pattern(dataset)
          when /crashlytics/i then target_datasets[:crashlytics] = dataset_pattern(dataset)
          end
        end
        target_datasets
      end
    end

    # Build the dataset pattern for query purposes
    def dataset_pattern(dataset)
      "#{dataset.project_id}.#{dataset.dataset_id}.*"
    end

    # Firebase APIs
    def firebase_management_service
      Installations::Google::Firebase::Api.new(project_number, json_key)
    end

    def firebase_client
      execute { firebase_management_service.set_firebase_client }
    end

    # Query string for Crashlytics data
    def crashlytics_query(dataset_name)
      execute { build_crashlytics_query(dataset_name) }
    end

    # Query string for Analytics data
    def analytics_query(dataset_name, app_id)
      execute { build_analytics_query(dataset_name, app_id) }
    end

    # Run the BigQuery query and fetch the data
    def get_data(query)
      bigquery_client.query(query)
    end

    # Fetch release data (memoized to avoid unnecessary calls)
    def release_data(app_id)
      @release_data ||= begin
        analytics_data = get_data(analytics_query(datasets[:ga4], app_id))
        crashlytics_data = get_data(crashlytics_query(datasets[:crashlytics]))
        {analytics_data: analytics_data, crashlytics_data: crashlytics_data}
      end
    end

    # Build the SQL query for Crashlytics data
    def build_crashlytics_query(dataset_name)
      <<-SQL.squish
        WITH combined_events AS (
          SELECT * FROM `#{dataset_name}`
        ),
        latest_version AS (
          SELECT MAX(application.display_version) AS latest_build_version
          FROM combined_events
        ),
        errors_with_version AS (
          SELECT
            issue_id,
            application.display_version AS version_name,
            application.build_version AS version_code,
            error_type
          FROM combined_events
          WHERE error_type IS NOT NULL
        ),
        previous_errors AS (
          SELECT DISTINCT issue_id
          FROM errors_with_version
          WHERE version_name < (SELECT MAX(application.display_version) FROM combined_events)
        ),
        new_errors AS (
          SELECT
            e.issue_id,
            e.version_name,
            e.version_code
          FROM errors_with_version e
          JOIN latest_version lv ON e.version_name = lv.latest_build_version
          LEFT JOIN previous_errors pe ON e.issue_id = pe.issue_id
          WHERE pe.issue_id IS NULL
        )
        SELECT
          e.version_name AS version_name,
          COUNT(*) AS errors_count,
          COUNT(DISTINCT ne.issue_id) AS new_errors_count
        FROM errors_with_version e
        LEFT JOIN new_errors ne ON e.issue_id = ne.issue_id
        GROUP BY e.version_name
        ORDER BY e.version_name;
      SQL
    end

    # Build the SQL query for Analytics data
    def build_analytics_query(dataset_name, app_id)
      <<-SQL.squish
        WITH combined_events AS (
          SELECT * FROM `#{dataset_name}`
        ),
        total_sessions AS (
          SELECT COUNTIF(event_name = 'session_start' AND event_timestamp >= UNIX_SECONDS(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY))) AS total_sessions_in_last_day
          FROM combined_events
        )
        SELECT
          app_info.version AS version_name,
          COUNT(CASE WHEN event_name = 'session_start' THEN 1 END) AS sessions,
          COUNT(DISTINCT COALESCE(user_id, user_pseudo_id)) AS daily_users,
          COUNT(DISTINCT CASE WHEN event_name = 'session_start' AND event_timestamp >= UNIX_SECONDS(TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)) THEN COALESCE(user_id, user_pseudo_id) END) AS sessions_in_last_day,
          COUNTIF(event_name = 'app_exception') AS sessions_with_errors,
          ts.total_sessions_in_last_day AS total_sessions_in_last_day,
          COUNT(DISTINCT CASE WHEN event_name = 'app_exception' THEN COALESCE(user_id, user_pseudo_id) END) AS daily_users_with_errors
        FROM combined_events, total_sessions AS ts
        WHERE app_info.firebase_app_id = '#{app_id}'
        GROUP BY app_info.version, ts.total_sessions_in_last_day
        ORDER BY app_info.version;
      SQL
    end

    # Parse JSON key
    def key_file
      json_key.rewind
      JSON.parse(json_key.read)
    end

    # Handle errors
    def execute
      yield
    rescue => e
      elog(e)
      nil
    end
  end
end
