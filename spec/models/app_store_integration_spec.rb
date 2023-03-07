require "rails_helper"

describe AppStoreIntegration do
  it "has a valid factory" do
    expect(create(:app_store_integration, :without_callbacks_and_validations)).to be_valid
  end

  describe "#find_live_release" do
    let(:integration) { create(:integration, :with_app_store) }
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

    it "returns failed to be true when live release is rejected" do
      allow(api_double).to receive(:find_live_release).and_return(rejected_release_response)
      result = app_store_integration.find_live_release.value!

      expect(result.failed?).to be(true)
    end

    it "returns neither success nor failed to be true when live release is in review" do
      allow(api_double).to receive(:find_live_release).and_return(in_review_release_response)
      result = app_store_integration.find_live_release.value!

      expect(result.success?).to be(false)
      expect(result.failed?).to be(false)
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
    let(:integration) { create(:integration, :with_app_store) }
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
        expect(result.found?).to be(true)
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
end
