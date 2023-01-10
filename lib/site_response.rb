module SiteHTTP
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
      raise InvalidStatus if Rack::Utils::SYMBOL_TO_STATUS_CODE.exclude?(@status)
    end
  end
end

