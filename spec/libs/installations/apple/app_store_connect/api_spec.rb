require "rails_helper"
require "webmock/rspec"

describe Installations::Apple::AppStoreConnect::Api, type: :integration do
  let(:bundle_id) { Faker::Lorem.word }
  let(:key_id) { Faker::Lorem.word }
  let(:issuer_id) { Faker::Lorem.word }
  let(:key) { Faker::Lorem.word }
  let(:build_number) { Faker::Number.number(digits: 7).to_s }

  before do
    allow_any_instance_of(described_class).to receive(:access_token).and_return(Faker::Lorem.word)
    allow_any_instance_of(described_class).to receive(:appstore_connect_token).and_return(Faker::Lorem.word)
  end

  context "when 5xx from applelink" do
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release?build_number=#{build_number}" }

    it "raises an error with unknown failure as reason" do
      request = stub_request(:get, url).to_return(status: 500)

      expect {
        described_class.new(bundle_id, key_id, issuer_id, key).find_release(build_number, AppStoreIntegration::RELEASE_TRANSFORMATIONS)
      }.to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:unknown_failure) }
      expect(request).to have_been_made
    end
  end

  describe "#find_release" do
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release?build_number=#{build_number}" }

    it "returns the transformed release for the build number" do
      request = stub_request(:get, url).to_return(body: File.read("spec/fixtures/app_store_connect/release.json"))
      expected_release = {
        external_id: "31aafef2-d5fb-45d4-9b02-f0ab5911c1b2",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        added_at: "2023-02-25T03:02:46-08:00",
        phased_release_day: 1,
        phased_release_status: "ACTIVE"
      }.with_indifferent_access

      result = described_class.new(bundle_id, key_id, issuer_id, key).find_release(build_number, AppStoreIntegration::RELEASE_TRANSFORMATIONS)

      expect(result).to eq(expected_release)
      expect(request).to have_been_made
    end

    it "raises an error when release not found for build number" do
      payload = {error: {code: "not_found", resource: "release"}}.to_json
      request = stub_request(:get, url).to_return(body: payload, status: 404)

      expect {
        described_class.new(bundle_id, key_id, issuer_id, key).find_release(build_number, AppStoreIntegration::RELEASE_TRANSFORMATIONS)
      }.to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:release_not_found) }
      expect(request).to have_been_made
    end
  end

  describe "#find_live_release" do
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/live" }

    it "returns the transformed live release" do
      request = stub_request(:get, url).to_return(body: File.read("spec/fixtures/app_store_connect/release.json"))
      expected_release = {
        external_id: "31aafef2-d5fb-45d4-9b02-f0ab5911c1b2",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        added_at: "2023-02-25T03:02:46-08:00",
        phased_release_day: 1,
        phased_release_status: "ACTIVE"
      }.with_indifferent_access

      result = described_class.new(bundle_id, key_id, issuer_id, key).find_live_release(AppStoreIntegration::RELEASE_TRANSFORMATIONS)

      expect(result).to eq(expected_release)
      expect(request).to have_been_made
    end

    it "raises an error when live release is not found" do
      payload = {error: {code: "not_found", resource: "release"}}.to_json
      request = stub_request(:get, url).to_return(body: payload, status: 404)

      expect {
        described_class.new(bundle_id, key_id, issuer_id, key).find_live_release(AppStoreIntegration::RELEASE_TRANSFORMATIONS)
      }.to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:release_not_found) }
      expect(request).to have_been_made
    end
  end

  describe "#prepare_release!" do
    let(:version) { "1.2.0" }
    let(:is_phased_release) { true }
    let(:metadata) { {whats_new: "The latest version contains bug fixes and performance improvements."} }
    let(:params) {
      {
        json: {
          build_number:,
          version:,
          is_phased_release:,
          is_force: true,
          metadata: metadata
        }
      }
    }
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/prepare" }

    it "returns the prepared release when success" do
      payload = File.read("spec/fixtures/app_store_connect/release.json")
      expected_release = {
        external_id: "31aafef2-d5fb-45d4-9b02-f0ab5911c1b2",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        added_at: "2023-02-25T03:02:46-08:00",
        phased_release_day: 1,
        phased_release_status: "ACTIVE"
      }.with_indifferent_access

      request = stub_request(:post, url).to_return(body: payload)
      result = described_class.new(bundle_id, key_id, issuer_id, key)
        .prepare_release(build_number, version, is_phased_release, metadata, true, AppStoreIntegration::RELEASE_TRANSFORMATIONS)

      expect(result).to eq(expected_release)
      expect(request.with(body: params[:json])).to have_been_made
    end

    it "returns error when preparing release is a failure" do
      error_payload = {error: {code: "export_compliance_not_updateable", resource: "build"}}.to_json
      request = stub_request(:post, url).to_return(status: 422, body: error_payload)

      expect {
        described_class.new(bundle_id, key_id, issuer_id, key)
          .prepare_release(build_number, version, is_phased_release, metadata, true, AppStoreIntegration::RELEASE_TRANSFORMATIONS)
      }
        .to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:missing_export_compliance) }
      expect(request.with(body: params[:json])).to have_been_made
    end
  end

  describe "#submit_release!" do
    let(:version) { Faker::Lorem.word }
    let(:params) {
      {
        json: {
          build_number: build_number,
          version: version
        }
      }
    }
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/submit" }

    it "returns true when submitting release is a success" do
      request = stub_request(:patch, url).to_return(status: 204)
      result = described_class.new(bundle_id, key_id, issuer_id, key).submit_release(build_number, version)

      expect(result).to be(true)
      expect(request.with(body: params[:json])).to have_been_made
    end

    it "returns error when submitting release is a failure" do
      error_payload = {error: {resource: "release", code: "review_in_progress"}}.to_json
      request = stub_request(:patch, url).to_return(status: 422, body: error_payload)

      expect { described_class.new(bundle_id, key_id, issuer_id, key).submit_release(build_number, version) }
        .to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:review_in_progress) }

      expect(request.with(body: params[:json])).to have_been_made
    end
  end

  describe "#start_release!" do
    let(:params) {
      {
        json: {
          build_number: build_number
        }
      }
    }
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/start" }

    it "returns true when starting release is a success" do
      request = stub_request(:patch, url).to_return(status: 204)
      result = described_class.new(bundle_id, key_id, issuer_id, key).start_release(build_number)

      expect(result).to be(true)
      expect(request.with(body: params[:json])).to have_been_made
    end

    it "returns error when starting release is a failure" do
      error_payload = {error: {resource: "build", code: "not_found"}}.to_json
      request = stub_request(:patch, url).to_return(status: 404, body: error_payload)

      expect { described_class.new(bundle_id, key_id, issuer_id, key).start_release(build_number) }
        .to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:build_not_found) }

      expect(request.with(body: params[:json])).to have_been_made
    end
  end

  describe "#complete_phased_release!" do
    let(:url) { "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/live/rollout/complete" }

    it "returns live release info when success" do
      request = stub_request(:patch, url).to_return(status: 200, body: File.read("spec/fixtures/app_store_connect/live_release.json"))
      result = described_class.new(bundle_id, key_id, issuer_id, key).complete_phased_release(AppStoreIntegration::RELEASE_TRANSFORMATIONS)

      expected_release = {
        external_id: "31aafef2-d5fb-45d4-9b02-f0ab5911c1b2",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        added_at: "2023-02-25T03:02:46-08:00",
        phased_release_day: 4,
        phased_release_status: "COMPLETE"
      }.with_indifferent_access

      expect(result).to eq(expected_release)
      expect(request).to have_been_made
    end

    it "raises an error when failure" do
      error_payload = {error: {resource: "release", code: "phased_release_not_found"}}.to_json
      request = stub_request(:patch, url).to_return(status: 404, body: error_payload)

      expect { described_class.new(bundle_id, key_id, issuer_id, key).complete_phased_release(AppStoreIntegration::RELEASE_TRANSFORMATIONS) }
        .to raise_error(Installations::Apple::AppStoreConnect::Error) { |error| expect(error.reason).to eq(:phased_release_not_found) }

      expect(request).to have_been_made
    end
  end
end
