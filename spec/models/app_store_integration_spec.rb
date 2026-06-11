require "rails_helper"

describe AppStoreIntegration do
  it "has a valid factory" do
    expect(create(:app_store_integration, :without_callbacks_and_validations)).to be_valid
  end

  describe "#find_live_release" do
    let(:app) { create(:app, platform: :ios) }
    let(:integration) { create(:integration, :with_app_store, integrable: app) }
    let(:app_store_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Apple::AppStoreConnect::Api) }
    let(:live_release_response) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "READY_FOR_SALE",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 1,
        phased_release_status: "ACTIVE"
      }
    }

    let(:pending_dev_release_response) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "PENDING_DEVELOPER_RELEASE",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 0,
        phased_release_status: "INACTIVE"
      }
    }

    let(:rejected_release_response) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "REJECTED",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 0,
        phased_release_status: "INACTIVE"
      }
    }

    let(:failed_release_response) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "DEVELOPER_REJECTED",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 0,
        phased_release_status: "INACTIVE"
      }
    }

    let(:in_review_release_response) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        status: "IN_REVIEW",
        build_number: "33417",
        name: "1.8.0",
        phased_release_day: 0,
        phased_release_status: "INACTIVE"
      }
    }

    before do
      allow(app_store_integration).to receive(:installation).and_return(api_double)
    end

    context "when released" do
      before do
        allow(api_double).to receive(:find_live_release).and_return(live_release_response)
      end

      it "finds live release and returns a ReleaseInfo" do
        result = app_store_integration.find_live_release.value!

        expect(result).to be_a(AppStoreIntegration::AppStoreReleaseInfo)
      end

      it "live release to be live for the correct build number" do
        result = app_store_integration.find_live_release.value!

        expect(result.live?("33417")).to be(true)
      end

      it "live release to be not live for the incorrect build number" do
        result = app_store_integration.find_live_release.value!

        expect(result.live?("9000")).to be(false)
      end
    end

    it "returns success to be true when live release is pending developer release" do
      allow(api_double).to receive(:find_live_release).and_return(pending_dev_release_response)
      result = app_store_integration.find_live_release.value!

      expect(result.success?).to be(true)
    end

    it "returns review failed to be true when live release is rejected" do
      allow(api_double).to receive(:find_live_release).and_return(rejected_release_response)
      result = app_store_integration.find_live_release.value!

      expect(result.review_failed?).to be(true)
    end

    it "returns review cancelled to be true when live release is developer rejected" do
      allow(api_double).to receive(:find_live_release).and_return(failed_release_response)
      result = app_store_integration.find_live_release.value!

      expect(result.review_cancelled?).to be(true)
    end

    it "returns neither success nor review cancelled to be true when live release is in review" do
      allow(api_double).to receive(:find_live_release).and_return(in_review_release_response)
      result = app_store_integration.find_live_release.value!

      expect(result.success?).to be(false)
      expect(result.review_cancelled?).to be(false)
    end

    it "returns failed result with release not found reason when live release not found" do
      error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "release"}})
      allow(api_double).to receive(:find_live_release).and_raise(error)
      result = app_store_integration.find_live_release

      expect(result.ok?).to be(false)
      expect(result.error.reason).to be(:release_not_found)
    end
  end

  describe "#find_build" do
    let(:app) { create(:app, platform: :ios) }
    let(:integration) { create(:integration, :with_app_store, integrable: app) }
    let(:app_store_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Apple::AppStoreConnect::Api) }
    let(:build_number) { Faker::Number.number(digits: 7).to_s }

    before do
      allow(app_store_integration).to receive(:installation).and_return(api_double)
    end

    context "when build found" do
      let(:build_response) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.8.0",
          build_number: build_number,
          status: "IN_BETA_REVIEW",
          added_at: Time.current.to_s
        }
      }
      let(:failure_build_response) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.8.0",
          build_number: build_number,
          status: "EXPIRED",
          added_at: Time.current.to_s
        }
      }
      let(:rejected_build_response) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.8.0",
          build_number: build_number,
          status: "BETA_REJECTED",
          added_at: Time.current.to_s
        }
      }
      let(:successful_build_response) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.8.0",
          build_number: build_number,
          status: "IN_BETA_TESTING",
          added_at: Time.current.to_s
        }
      }

      it "finds build for build number and returns a TestFlightInfo" do
        allow(api_double).to receive(:find_build).with(build_number, AppStoreIntegration::BUILD_TRANSFORMATIONS).and_return(build_response)
        result = app_store_integration.find_build(build_number).value!

        expect(result).to be_a(AppStoreIntegration::TestFlightInfo)
        expect(result.build_info).to be_present
      end

      it "returns neither success nor failed to be true when build is in process" do
        allow(api_double).to receive(:find_build).with(build_number, AppStoreIntegration::BUILD_TRANSFORMATIONS).and_return(build_response)
        result = app_store_integration.find_build(build_number).value!

        expect(result.success?).to be(false)
        expect(result.failed?).to be(false)
      end

      it "returns success to be true when successful build" do
        allow(api_double).to receive(:find_build).with(build_number, AppStoreIntegration::BUILD_TRANSFORMATIONS).and_return(successful_build_response)
        result = app_store_integration.find_build(build_number).value!

        expect(result.success?).to be(true)
        expect(result.failed?).to be(false)
      end

      it "returns failed to be true when failed build" do
        allow(api_double).to receive(:find_build).with(build_number, AppStoreIntegration::BUILD_TRANSFORMATIONS).and_return(failure_build_response)
        result = app_store_integration.find_build(build_number).value!

        expect(result.success?).to be(false)
        expect(result.failed?).to be(true)
      end

      it "returns review failed to be true when rejected build" do
        allow(api_double).to receive(:find_build).with(build_number, AppStoreIntegration::BUILD_TRANSFORMATIONS).and_return(rejected_build_response)
        result = app_store_integration.find_build(build_number).value!

        expect(result.success?).to be(false)
        expect(result.failed?).to be(false)
        expect(result.review_failed?).to be(true)
      end
    end

    context "when build not found" do
      it "returns a failed result with build not found reason" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "build"}})
        allow(api_double).to receive(:find_build).with(build_number, AppStoreIntegration::BUILD_TRANSFORMATIONS).and_raise(error)

        result = app_store_integration.find_build(build_number)

        expect(result.ok?).to be(false)
        expect(result.error.reason).to be(:build_not_found)
      end
    end
  end

  describe "#rotate" do
    let(:app) { create(:app, platform: :ios, bundle_identifier: "com.example.app") }
    let(:integration) { create(:integration, :with_app_store, integrable: app) }
    let(:app_store_integration) { integration.providable }
    let(:api_double) { instance_double(Installations::Apple::AppStoreConnect::Api) }
    let(:new_p8) { "-----BEGIN EC PRIVATE KEY-----\nNEW\n-----END EC PRIVATE KEY-----" }
    let(:new_attrs) { {key_id: "NEW_KEY", issuer_id: "NEW_ISSUER", p8_key: new_p8} }

    before do
      allow(OpenSSL::PKey::EC).to receive(:new).with(new_p8).and_return(instance_double(OpenSSL::PKey::EC))
      allow(Installations::Apple::AppStoreConnect::Api).to receive(:new)
        .with("com.example.app", "NEW_KEY", "NEW_ISSUER", anything)
        .and_return(api_double)
    end

    it "verifies new credentials, persists them, and returns true on success" do
      allow(api_double).to receive(:find_app).and_return({id: "123", name: "App", bundle_id: "com.example.app"})

      expect(app_store_integration.rotate(**new_attrs)).to be(true)
      expect(app_store_integration.reload.key_id).to eq("NEW_KEY")
      expect(app_store_integration.reload.issuer_id).to eq("NEW_ISSUER")
      expect(app_store_integration.reload.p8_key).to eq(new_p8)
    end

    it "does not persist new credentials and surfaces a :key_id error when verification fails" do
      original_key_id = app_store_integration.key_id
      error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "unauthorized", "resource" => "app"}})
      allow(api_double).to receive(:find_app).and_raise(error)

      expect(app_store_integration.rotate(**new_attrs)).to be(false)
      expect(app_store_integration.errors[:key_id]).to be_present
      expect(app_store_integration.reload.key_id).to eq(original_key_id)
    end
  end

  describe "AppStoreReleaseInfo#phased_release_stage" do
    let(:release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(release_data) }

    context "when phased release is complete" do
      let(:release_data) { {phased_release_status: "COMPLETE", phased_release_day: 3} }

      it "returns the final stage index" do
        expect(release_info.phased_release_stage).to eq(6)
      end
    end

    it "returns correct stage for first phased release day" do
      release_info = AppStoreIntegration::AppStoreReleaseInfo.new({phased_release_status: "ACTIVE", phased_release_day: 1})
      expect(release_info.phased_release_stage).to eq(0)
    end

    it "returns correct stage for middle phased release day" do
      release_info = AppStoreIntegration::AppStoreReleaseInfo.new({phased_release_status: "ACTIVE", phased_release_day: 3})
      expect(release_info.phased_release_stage).to eq(2)
    end

    it "returns final stage when at maximum phased release day" do
      release_info = AppStoreIntegration::AppStoreReleaseInfo.new({phased_release_status: "ACTIVE", phased_release_day: 7})
      expect(release_info.phased_release_stage).to eq(6)
    end

    it "returns final stage when beyond maximum phased release day" do
      release_info = AppStoreIntegration::AppStoreReleaseInfo.new({phased_release_status: "ACTIVE", phased_release_day: 10})
      expect(release_info.phased_release_stage).to eq(6)
    end
  end
end
