require "ipaddr"
require "resolv"

module LifecycleHooks
  # Executes a single LifecycleHook's HTTP request with a given context.
  # Returns a GitHub::Result wrapping the response hash or a failure.
  class Runner
    BlockedTargetError = Class.new(StandardError)
    TemplateError = Class.new(StandardError)

    # Total wall-clock budget for the whole request (connect + write + read). A global
    # timeout — unlike per-operation timeouts, which reset on every read — bounds the
    # overall time so a server that trickles bytes cannot hold the worker thread open
    # indefinitely.
    TIMEOUT_SECONDS = 15
    RESPONSE_BODY_PREVIEW = 500

    BLOCKED_CIDRS = %w[
      10.0.0.0/8
      172.16.0.0/12
      192.168.0.0/16
      127.0.0.0/8
      169.254.0.0/16
      0.0.0.0/8
      ::1/128
      fc00::/7
      fe80::/10
      ::ffff:0:0/96
      ::/128
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    HEADER_FORBIDDEN_CHARS = /[\r\n]/

    def self.call(hook, context)
      new(hook, context).call
    end

    def initialize(hook, context)
      @hook = hook
      @context = context
    end

    def call
      GitHub::Result.new do
        body = rendered_body
        request_headers = rendered_headers
        validate_url_host!
        response = perform_request(body, request_headers)
        {
          status: response.code,
          success: response.status.success?,
          body_preview: bounded_body_preview(response)
        }
      end
    end

    private

    attr_reader :hook, :context

    def perform_request(body, request_headers)
      verb = hook.http_method.downcase.to_sym

      client = HTTP.timeout(TIMEOUT_SECONDS)
      client = client.headers(request_headers) if request_headers.any?
      client = apply_auth(client)

      if body.nil?
        client.public_send(verb, hook.url)
      else
        client.public_send(verb, hook.url, body: body)
      end
    end

    # Reads at most RESPONSE_BODY_PREVIEW bytes from the response, then closes the
    # connection, so we never buffer a large (or unbounded) response body into memory.
    def bounded_body_preview(response)
      preview = String.new(encoding: Encoding::BINARY)
      stream = response.body
      while preview.bytesize < RESPONSE_BODY_PREVIEW && (chunk = stream.readpartial(RESPONSE_BODY_PREVIEW))
        preview << chunk
      end
      preview.byteslice(0, RESPONSE_BODY_PREVIEW)
    ensure
      response.connection.close
    end

    def apply_auth(client)
      case hook.auth_type
      when "basic"
        client.basic_auth(user: hook.auth_username, pass: hook.auth_secret)
      when "bearer"
        client.auth("Bearer #{hook.auth_secret}")
      else
        client
      end
    end

    def rendered_headers
      (hook.headers || {}).transform_values do |v|
        rendered = render_template(v.to_s, json_escape: false)
        raise BlockedTargetError, "Header value contains forbidden characters" if rendered.match?(HEADER_FORBIDDEN_CHARS)
        rendered
      end
    end

    def rendered_body
      return nil if hook.body_template.blank?
      render_template(hook.body_template, json_escape: json_body?)
    end

    def json_body?
      hook.headers.to_h.any? { |k, v| k.to_s.downcase == "content-type" && v.to_s.downcase.include?("json") }
    end

    def render_template(template, json_escape:)
      variables = merged_variables
      template.gsub(/%\{(\w+)\}/) do
        key = Regexp.last_match(1)
        value = variables.fetch(key) { raise TemplateError, "Unknown variable: %{#{key}}" }
        json_escape ? escape_for_json(value) : value.to_s
      end
    end

    def merged_variables
      hook.static_variables.to_h.transform_keys(&:to_s).merge(context.transform_keys(&:to_s))
    end

    # Preserves JSON validity for scalar substitution. Integers/floats/true/false/nil stay unquoted
    # when used without surrounding quotes in the template; otherwise strings get escaped.
    def escape_for_json(value)
      return value.to_s if value.is_a?(Numeric) || value == true || value == false
      JSON.generate(value.to_s)[1..-2] # strip the wrapping quotes, return escaped contents
    end

    def validate_url_host!
      # `URI#hostname` strips brackets from IPv6 literals (unlike `#host`).
      host = URI.parse(hook.url).hostname
      raise BlockedTargetError, "URL has no host" if host.blank?

      # If the host is itself an IP literal, check it directly.
      literal_ip = parse_ip(host)
      if literal_ip
        check_blocked!(literal_ip)
        return
      end

      # Otherwise resolve the hostname ourselves and validate every returned address. We must
      # NOT fall through to the HTTP client when resolution yields nothing: alternative IP
      # encodings that IPAddr/Resolv reject (octal `0177.0.0.1`, integer `2130706433`,
      # hex `0x7f.0.0.1`) would otherwise be resolved and connected to by the OS socket layer,
      # bypassing this guard. Failing closed here blocks them.
      addresses =
        begin
          Resolv.getaddresses(host)
        rescue
          []
        end
      raise BlockedTargetError, "Could not resolve host" if addresses.empty?

      # NOTE: this is a request-time check that does not pin the resolved IP, so it does not
      # defend against DNS rebinding (a TOCTOU where the host resolves to a public address here
      # but to a private one when the HTTP client re-resolves). Hooks are configured by trusted
      # train admins, so this guard is defense-in-depth; pinning the resolved IP is intentionally
      # out of scope for this change.
      addresses.each do |addr|
        ip = parse_ip(addr)
        check_blocked!(ip) if ip
      end
    end

    def parse_ip(str)
      IPAddr.new(str)
    rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
      nil
    end

    def check_blocked!(ip)
      # Normalize IPv4-mapped IPv6 (::ffff:127.0.0.1) to its IPv4 form for CIDR matching.
      normalized = ip.ipv4_mapped? ? ip.native : ip
      return unless BLOCKED_CIDRS.any? { |range| range.include?(normalized) }
      raise BlockedTargetError, "URL resolves to a blocked address range"
    end
  end
end
