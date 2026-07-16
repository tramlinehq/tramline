require "rails_helper"

describe LifecycleHook do
  describe "validations" do
    it "is valid with default factory" do
      hook = build(:lifecycle_hook)
      expect(hook).to be_valid
    end

    it "requires name, event, http_method, url" do
      hook = build(:lifecycle_hook, name: nil, event: nil, http_method: nil, url: nil)
      expect(hook).not_to be_valid
      expect(hook.errors).to include(:name, :event, :http_method, :url)
    end

    it "rejects non-http urls" do
      hook = build(:lifecycle_hook, url: "ftp://example.com")
      expect(hook).not_to be_valid
      expect(hook.errors[:url]).to be_present
    end

    it "rejects unknown events" do
      expect { build(:lifecycle_hook, event: "unknown_event") }.to raise_error(ArgumentError)
    end

    it "requires username and secret for basic auth" do
      hook = build(:lifecycle_hook, auth_type: "basic", auth_username: nil, auth_secret: nil)
      expect(hook).not_to be_valid
      expect(hook.errors[:auth_username]).to be_present
      expect(hook.errors[:auth_secret]).to be_present
    end

    it "requires secret for bearer auth" do
      hook = build(:lifecycle_hook, auth_type: "bearer", auth_secret: nil)
      expect(hook).not_to be_valid
      expect(hook.errors[:auth_secret]).to be_present
    end

    it "allows notify_on_failure without a channel (notification is best-effort at runtime)" do
      hook = build(:lifecycle_hook, :with_failure_notify, failure_notification_channel: nil)
      expect(hook).to be_valid
    end
  end

  describe "available_variables" do
    it "returns system variables for the event plus custom static variables" do
      hook = build(:lifecycle_hook, event: "ios_submission_started", static_variables: {"admin_url" => "https://example.com"})
      expect(hook.available_variables).to include("build_number", "version", "platform", "admin_url")
    end
  end

  describe "headers_text / static_variables_text" do
    it "serializes headers hash to key: value lines" do
      hook = build(:lifecycle_hook, headers: {"Content-Type" => "application/json", "X-Custom" => "abc"})
      expect(hook.headers_text).to include("Content-Type: application/json")
      expect(hook.headers_text).to include("X-Custom: abc")
    end

    it "serializes static_variables hash to key: value lines" do
      hook = build(:lifecycle_hook, static_variables: {"admin_url" => "https://ex.com"})
      expect(hook.static_variables_text).to eq("admin_url: https://ex.com")
    end
  end
end
