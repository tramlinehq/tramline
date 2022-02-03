module Installations
  require "openssl"
  require "jwt"

  class Github::Jwt
    attr_reader :private_key, :app_id

    def initialize(app_id)
      @app_id = app_id
      private_pem = Rails.application.credentials.integrations.github.private_pem
      @private_key = OpenSSL::PKey::RSA.new(private_pem)
    end

    def fetch
      payload = {
        # issued at time, 60 seconds in the past to allow for clock drift
        iat: Time.now.to_i - 60,
        exp: Time.now.to_i + (10 * 60),
        iss: app_id
      }

      JWT.encode(payload, private_key, "RS256")
    end
  end
end
