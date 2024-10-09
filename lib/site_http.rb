module SiteHttp
  class Response
    class InvalidStatus < ArgumentError; end

    def initialize(status, body = nil)
      @status = status
      @body = body
      validate_status
    end

    attr_reader :status, :body

    def success?
      status.in? [:ok, :created, :accepted, :no_content]
    end

    private

    def validate_status
      Rack::Utils.status_code(@status)
    rescue ArgumentError
      raise InvalidStatus
    end
  end
end
