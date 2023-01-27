module Installations
  require "openssl"
  require "jwt"

  class Apple::AppStoreConnect::Jwt
    MAX_TOKEN_DURATION = 1000

    def self.encode(**params)
      new(**params).encode
    end

    def initialize(key:, algo:, aud:, iss:, header: {})
      @key = key
      @algo = algo
      @aud = aud
      @iss = iss
      @header = header
    end

    def encode
      JWT.encode(payload, key, algo, header)
    end

    private

    attr_reader :key, :algo, :header
    attr_reader :aud, :iss

    def payload
      now = Time.current
      exp = now + MAX_TOKEN_DURATION

      {
        iat: now.to_i,
        exp: exp.to_i,
        aud: aud,
        iss: iss
      }
    end
  end
end
