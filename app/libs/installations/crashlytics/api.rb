# api.rb
require "google/cloud/bigquery"
require "json"
require_relative 'error'

module Installations
  class Crashlytics::Api

    BIGQUERY = ::Google::Cloud::Bigquery

    attr_reader :json_key, :project_number, :bigquery_client

    def initialize(project_number, json_key)
      @project_number = project_number
      @json_key = json_key
    end

    # Bigquery Apis

    def find_release(app_id, app_version, app_version_code, transforms)
      execute do
        releases = list_releases(project_id).presence || []
        return if releases.blank?

        releases
          .filter { |r| r.app_version == app_version && (r.app_version_code == app_version_code || r.app_bundle_version == app_version_code) }
          .map { _1.to_h.merge(total_sessions_count_in_last_24h: releases.pluck(:sessions_count_in_last_24h).sum) }
          .then { Installations::Response::Keys.transform(_1, transforms) }
          .first
      end
    end

    def list_releases(app_id)

    end

    def bigquery_client
      @bigquery_client ||=  BIGQUERY.new(credentials: key_file)
    end

    def datasets
      target_tables = {}

      bigquery_client.datasets.each do |dataset|
        if dataset.dataset_id.match?(/^analytics_\d+$/) || dataset.dataset_id.downcase.include?("crashlytics")
          target_tables[dataset.dataset_id] = dataset.tables.map(&:table_id)
        end
      end
    end

    def analytics_query
      <<-SQL
          WITH combined_events AS (
              SELECT * FROM `decoded-theme-355014.analytics_372707921.events_*`
              UNION ALL
              SELECT * FROM `decoded-theme-355014.analytics_372707921.events_intraday_*`
          )

          SELECT 
              app_info.version AS version,
              COUNT(CASE WHEN event_name = 'session_start' THEN 1 END) as sessions




              COUNT(DISTINCT COALESCE(user_id, user_pseudo_id)) AS daily_users,
              COUNT(DISTINCT CASE WHEN event_name = 'app_exception' THEN COALESCE(user_id, user_pseudo_id) END) AS daily_users_with_errors,
              COUNT(CASE WHEN event_name = 'app_exception' THEN 1 END) AS errors_count,
              COUNT(CASE WHEN event_name = 'app_exception' 
                         AND event_timestamp >= 946684800000  -- Jan 1, 2000 in milliseconds
                         AND event_timestamp <= UNIX_MICROS(CURRENT_TIMESTAMP()) / 1000
                         AND TIMESTAMP_SECONDS(CAST(event_timestamp / 1000 AS INT64)) >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) THEN 1 END) AS new_errors_count,
              COUNT(DISTINCT CASE WHEN event_name = 'session_start' THEN COALESCE(user_id, user_pseudo_id) END) AS sessions,
              COUNT(DISTINCT CASE WHEN event_name = 'session_start' 
                         AND event_timestamp >= 946684800000
                         AND event_timestamp <= UNIX_MICROS(CURRENT_TIMESTAMP()) / 1000
                         AND TIMESTAMP_SECONDS(CAST(event_timestamp / 1000 AS INT64)) >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) THEN COALESCE(user_id, user_pseudo_id) END) AS sessions_in_last_day,
              COUNT(DISTINCT CASE WHEN event_name = 'session_start' AND EXISTS (
                  SELECT 1 FROM UNNEST(event_params) AS param
                  WHERE param.key = 'firebase_error' AND param.value.int_value IS NOT NULL
              ) THEN COALESCE(user_id, user_pseudo_id) END) AS sessions_with_errors,
              COUNT(DISTINCT CASE WHEN event_name = 'session_start' 
                         AND event_timestamp >= 946684800000  -- Jan 1, 2000 in milliseconds
                         AND event_timestamp <= UNIX_MICROS(CURRENT_TIMESTAMP()) / 1000
                         AND TIMESTAMP_SECONDS(CAST(event_timestamp / 1000 AS INT64)) >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) THEN COALESCE(user_id, user_pseudo_id) END) AS total_sessions_in_last_day
          FROM combined_events
          WHERE event_date = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
          GROUP BY version
      SQL
    end

    #Firebase apis

    def firebase_management_service
      Installations::Google::Firebase::Api.new(project_number, json_key)
    end

    def list_apps(transforms)
      firebase_management_service.list_apps(transforms)
    end

    def firebase_client
      firebase_management_service.set_firebase_client
    end

    private

    def key_file
      json_key.rewind
      JSON.parse(json_key.read)
    end
  end
end
