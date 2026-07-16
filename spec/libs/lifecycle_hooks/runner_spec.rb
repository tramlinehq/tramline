require "rails_helper"

describe LifecycleHooks::Runner do
  let(:context) { {"build_number" => "12345", "version" => "1.2.3", "platform" => "ios", "admin_url" => "https://admin.example.com"} }

  describe "basic execution" do
    it "fires a PATCH with JSON-escaped body substitution and returns ok result" do
      hook = create(:lifecycle_hook,
        http_method: "PATCH",
        url: "https://external.example.com/api",
        headers: {"Content-Type" => "application/json"},
        body_template: '{"build_number": %{build_number}, "hide_markets": true}')

      stub_request(:patch, "https://external.example.com/api")
        .with(body: '{"build_number": 12345, "hide_markets": true}')
        .to_return(status: 200, body: '{"ok": true}')

      result = described_class.call(hook, context)
      expect(result.ok?).to be true
      expect(result.value![:success]).to be true
      expect(result.value![:status]).to eq(200)
    end

    it "applies basic auth" do
      hook = create(:lifecycle_hook, :basic_auth,
        http_method: "GET",
        url: "https://external.example.com/check",
        headers: {},
        body_template: nil)

      stub_request(:get, "https://external.example.com/check")
        .with(basic_auth: ["user", "secret"])
        .to_return(status: 200, body: "{}")

      result = described_class.call(hook, context)
      expect(result.ok?).to be true
    end

    it "applies bearer auth" do
      hook = create(:lifecycle_hook, :bearer_auth,
        http_method: "POST",
        url: "https://external.example.com/post",
        headers: {},
        body_template: "{}")

      stub_request(:post, "https://external.example.com/post")
        .with(headers: {"Authorization" => "Bearer token"})
        .to_return(status: 201)

      result = described_class.call(hook, context)
      expect(result.ok?).to be true
    end
  end

  describe "SSRF protection" do
    it "blocks localhost targets" do
      hook = create(:lifecycle_hook, url: "http://127.0.0.1/evil")

      result = described_class.call(hook, context)
      expect(result.ok?).to be false
      expect(result.error).to be_a(LifecycleHooks::Runner::BlockedTargetError)
    end

    it "blocks metadata endpoint IP" do
      hook = create(:lifecycle_hook, url: "http://169.254.169.254/latest/meta-data")

      result = described_class.call(hook, context)
      expect(result.ok?).to be false
      expect(result.error).to be_a(LifecycleHooks::Runner::BlockedTargetError)
    end

    it "blocks IPv6 loopback literal" do
      hook = create(:lifecycle_hook, url: "http://[::1]/evil")

      result = described_class.call(hook, context)
      expect(result.ok?).to be false
      expect(result.error).to be_a(LifecycleHooks::Runner::BlockedTargetError)
    end

    it "blocks IPv4-mapped IPv6 loopback" do
      hook = create(:lifecycle_hook, url: "http://[::ffff:127.0.0.1]/x")

      result = described_class.call(hook, context)
      expect(result.ok?).to be false
      expect(result.error).to be_a(LifecycleHooks::Runner::BlockedTargetError)
    end

    it "blocks CRLF-injected header values" do
      hook = create(:lifecycle_hook,
        url: "https://external.example.com/x",
        headers: {"X-Custom" => "%{release_branch}"},
        body_template: nil)
      stub_request(:post, "https://external.example.com/x")

      ctx = context.merge("release_branch" => "foo\r\nX-Injected: yes")
      result = described_class.call(hook, ctx)
      expect(result.ok?).to be false
      expect(result.error).to be_a(LifecycleHooks::Runner::BlockedTargetError)
    end
  end

  describe "template rendering" do
    it "raises on unknown variable" do
      hook = create(:lifecycle_hook,
        url: "https://external.example.com/x",
        headers: {},
        body_template: "hello %{unknown_var}")

      stub_request(:post, "https://external.example.com/x")

      result = described_class.call(hook, context)
      expect(result.ok?).to be false
      expect(result.error).to be_a(LifecycleHooks::Runner::TemplateError)
    end

    it "JSON-escapes string values when content-type is json" do
      hook = create(:lifecycle_hook,
        http_method: "POST",
        url: "https://external.example.com/j",
        headers: {"Content-Type" => "application/json"},
        body_template: '{"branch": "%{release_branch}"}')

      stub_request(:post, "https://external.example.com/j")
        .with(body: '{"branch": "feature/\"quoted\""}')
        .to_return(status: 200)

      ctx = context.merge("release_branch" => 'feature/"quoted"')
      result = described_class.call(hook, ctx)
      expect(result.ok?).to be true
    end
  end
end
