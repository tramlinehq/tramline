module Installations
  require "down/http"

  class Bugsnag::Api
    attr_reader :access_token

    LIST_ORGS_URL = "https://api.bugsnag.com/user/organizations"

    def initialize(access_token)
      @access_token = access_token
    end

    def list_organizations(transforms)
      execute(:get, LIST_ORGS_URL, {})
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    private

    def execute(verb, url, params)
      response = HTTP.auth(access_token.to_s).public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      body unless error?(response.status)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end
