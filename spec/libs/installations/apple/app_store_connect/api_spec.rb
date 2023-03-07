require "rails_helper"

describe Installations::Apple::AppStoreConnect::Api, type: :integration do
  let(:bundle_id) { Faker::Lorem.word }
  let(:key_id) { Faker::Lorem.word }
  let(:issuer_id) { Faker::Lorem.word }
  let(:key) { Faker::Lorem.word }
  let(:build_number) { Faker::Number.number(digits: 7).to_s }

  describe "#find_release" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/app_store_connect/release.json")) }

    it "returns the transformed release for the build number" do
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release"
      allow_any_instance_of(described_class).to receive(:execute).with(:get, url, {params: {build_number:}}).and_return(payload)
      result = described_class.new(bundle_id, key_id, issuer_id, key).find_release(build_number, AppStoreIntegration::RELEASE_TRANSFORMATIONS)

      expected_release = {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 1,
        phased_release_status: "ACTIVE"
      }.with_indifferent_access
      expect(result).to eq(expected_release)
    end

    it "raises an error when release not found for build number" do
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release"
      error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "release"}})
      allow_any_instance_of(described_class).to receive(:execute).with(:get, url, {params: {build_number:}}).and_raise(error)

      expect {
        described_class.new(bundle_id, key_id, issuer_id, key).find_release(build_number, AppStoreIntegration::RELEASE_TRANSFORMATIONS)
      }.to raise_error(error)
    end
  end

  describe "#find_live_release" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/app_store_connect/release.json")) }

    it "returns the transformed live release" do
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/live"
      allow_any_instance_of(described_class).to receive(:execute).with(:get, url, {}).and_return(payload)
      result = described_class.new(bundle_id, key_id, issuer_id, key).find_live_release(AppStoreIntegration::RELEASE_TRANSFORMATIONS)

      expected_release = {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 1,
        phased_release_status: "ACTIVE"
      }.with_indifferent_access
      expect(result).to eq(expected_release)
    end

    it "raises an error when live release is not found" do
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/live"
      error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "release"}})
      allow_any_instance_of(described_class).to receive(:execute).with(:get, url, {}).and_raise(error)

      expect {
        described_class.new(bundle_id, key_id, issuer_id, key).find_live_release(AppStoreIntegration::RELEASE_TRANSFORMATIONS)
      }.to raise_error(error)
    end
  end

  describe "#prepare_release!" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/app_store_connect/release.json")) }
    let(:version) { "1.2.0" }
    let(:is_phased_release) { true }

    it "returns true when submitting release is a success" do
      params = {
        json: {
          build_number:,
          version:,
          is_phased_release:,
          metadata: {
            description: "The true Yamanote line aural aesthetic.",
            whats_new: "Every station now has the JR Shinkansen badges for connecting Shinkansen lines."
          }
        }
      }
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/prepare"
      allow_any_instance_of(described_class).to receive(:execute).with(:post, url, params).and_return(payload)
      result = described_class.new(bundle_id, key_id, issuer_id, key).prepare_release(build_number, version, is_phased_release)

      expect(result).to eq(payload)
    end

    it "returns false when preparing release is a failure" do
      params = {
        json: {
          build_number:,
          version:,
          is_phased_release:,
          metadata: {
            description: "The true Yamanote line aural aesthetic.",
            whats_new: "Every station now has the JR Shinkansen badges for connecting Shinkansen lines."
          }
        }
      }
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/prepare"
      allow_any_instance_of(described_class).to receive(:execute).with(:post, url, params).and_return(false)
      result = described_class.new(bundle_id, key_id, issuer_id, key).prepare_release(build_number, version, is_phased_release)

      expect(result).to be(false)
    end
  end

  describe "#submit_release!" do
    it "returns true when submitting release is a success" do
      params = {
        json: {
          build_number: build_number
        }
      }
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/submit"
      allow_any_instance_of(described_class).to receive(:execute).with(:patch, url, params).and_return(true)
      result = described_class.new(bundle_id, key_id, issuer_id, key).submit_release(build_number)

      expect(result).to be(true)
    end

    it "returns false when submitting release is a failure" do
      params = {
        json: {
          build_number: build_number
        }
      }
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/submit"
      allow_any_instance_of(described_class).to receive(:execute).with(:patch, url, params).and_return(false)
      result = described_class.new(bundle_id, key_id, issuer_id, key).submit_release(build_number)

      expect(result).to be(false)
    end
  end

  describe "#start_release!" do
    it "returns true when starting release is a success" do
      params = {
        json: {
          build_number: build_number
        }
      }
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/start"
      allow_any_instance_of(described_class).to receive(:execute).with(:patch, url, params).and_return(true)
      result = described_class.new(bundle_id, key_id, issuer_id, key).start_release(build_number)

      expect(result).to be(true)
    end

    it "returns false when starting release is a failure" do
      params = {
        json: {
          build_number: build_number
        }
      }
      url = "http://localhost:4000/apple/connect/v1/apps/#{bundle_id}/release/start"
      allow_any_instance_of(described_class).to receive(:execute).with(:patch, url, params).and_return(false)
      result = described_class.new(bundle_id, key_id, issuer_id, key).start_release(build_number)

      expect(result).to be(false)
    end
  end
end
