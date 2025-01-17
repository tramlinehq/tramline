require "rails_helper"

describe StoreSubmissions::AppStore::FindBuildJob do
  describe "#perform" do
    let(:provider_dbl) { instance_double(AppStoreIntegration) }
    let(:build) { create(:build) }
    let(:submission) { create(:app_store_submission, :preparing, build: build) }
    let(:base_release_info) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        name: build.version_name,
        build_number: build.build_number,
        added_at: 1.day.ago,
        phased_release_status: "INACTIVE",
        phased_release_day: 0
      }
    }
    let(:prepared_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "PREPARE_FOR_SUBMISSION")) }

    before do
      allow(provider_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { prepared_release_info })
      allow_any_instance_of(AppStoreSubmission).to receive(:provider).and_return(provider_dbl)
    end

    it "when submission is not found" do
      expect { described_class.new.perform("fake_id") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "when build is present in the store, starts preparing the release" do
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { prepared_release_info })

      described_class.new.perform(submission.id)

      expect(provider_dbl).to have_received(:prepare_release).with(build.build_number, build.version_name, true, anything, true).once
    end

    it "handles build_not_found error and schedules a retry if retries are available" do
      build_not_found_error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "build"}})

      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise build_not_found_error })
      allow(described_class).to receive(:perform_in)

      described_class.new.perform(submission.id)

      expect(described_class).to have_received(:perform_in).with(
        60.seconds,
        submission.id,
        1
      ).once
    end
  end
end
