module Installations
  class Error < StandardError
    attr_reader :reason

    def initialize(msg, reason: nil)
      @reason = reason
      super(msg)
    end

    ResourceNotFound = Installations::Error.new("The resource was not found", reason: :resource_not_found)
    ServerError = Installations::Error.new("The server failed to fulfill the request", reason: :server_error)
    TokenRefreshFailure = Installations::Error.new("Failed to refresh oauth token", reason: :token_refresh_failure)
    TokenExpired = Installations::Error.new("Failed to acquire oauth token", reason: :token_expired)
  end
end

