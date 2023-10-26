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
        client
          .releases(project_id, per_page: 10, sort: "timestamp", release_stage: release_stage)
          .filter { |release| release.app_version == app_version && (release.app_version_code == app_version_code || release.app_bundle_version == app_version_code) }
          .then { |releases| Installations::Response::Keys.transform(releases, transforms) }
          .first
      end
    end

    private

    def execute
      yield
    rescue => e
      elog(e)
    end
  end
end
