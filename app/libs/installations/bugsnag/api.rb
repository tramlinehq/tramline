module Installations
  require "down/http"
  require "bugsnag/api"

  class Bugsnag::Api
    include Loggable
    attr_reader :client

    def initialize(access_token)
      @client = ::Bugsnag::Api::Client.new(auth_token: access_token)
    end

    def list_organizations(transforms)
      execute do
        client.organizations.then { |orgs| Installations::Response::Keys.transform(orgs, transforms) }
      end
    end

    def list_projects(org_id, transforms)
      execute do
        client.projects(org_id).then { |projects| Installations::Response::Keys.transform(projects, transforms) }
      end
    end

    def find_release(project_id, release_stage, app_version, app_version_code, transforms)
      execute do
        releases = list_releases(project_id, release_stage).presence || []
        return if releases.blank?

        releases
          .filter { |r| r.app_version == app_version && (r.app_version_code == app_version_code || r.app_bundle_version == app_version_code) }
          .map { _1.merge(total_sessions_count_in_last_24h: releases.pluck(:sessions_count_in_last_24h).sum) }
          .then { Installations::Response::Keys.transform(_1, transforms) }
          .first
      end
    end

    def list_releases(project_id, release_stage)
      execute do
        session_significance_factor = 0.001
        session_key = :sessions_count_in_last_24h
        per_page = 10
        offset = 0
        releases = []
        max_seen = 0
        max_iterations = 10

        loop.each_with_index do |_, iteration|
          break if iteration >= max_iterations
          new_releases = fetch_releases(project_id, per_page, offset, release_stage)
          break if new_releases.empty?
          local_max, local_min = new_releases.pluck(session_key).max, new_releases.pluck(session_key).min
          max_seen = [max_seen, local_max].max
          offset += per_page
          releases.concat(new_releases)
          break if local_min < (session_significance_factor * max_seen)
        end

        releases
      end
    end

    private

    def fetch_releases(project_id, per_page, offset, release_stage, sort = "percent_of_sessions")
      client.releases(project_id, per_page:, offset:, sort:, release_stage:)
    end

    def execute
      yield
    rescue => e
      elog(e)
      nil
    end
  end
end
