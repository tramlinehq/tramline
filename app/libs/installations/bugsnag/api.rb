module Installations
  require "down/http"
  require "bugsnag/api"

  class Bugsnag::Api
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

    def find_release(project_id, app_version, app_version_code)
      execute do
        client
          .releases(project_id)
          .find { |release| release.app_version == app_version && release.app_version_code == app_version_code }
      end
    end

    def events(project_id, platform, app_version, app_version_code)
      client.events(
        project_id,
        direction: "desc",
        filters: {
          "version.seen_in" => [{type: "eq", value: app_version}],
          "version_code.seen_in" => [{type: "eq", value: app_version_code}],
          "app.type" => [{type: "eq", value: platform}]
        }
      )
    end

    private

    def execute
      yield
    rescue => e
      Rails.logger.error(e)
    end
  end
end
