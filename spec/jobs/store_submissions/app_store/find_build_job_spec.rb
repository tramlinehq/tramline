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

    context "when build is present in the store" do
      it "starts preparing the release" do
        allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { prepared_release_info })
        described_class.new.perform(submission.id)
        expect(provider_dbl).to have_received(:prepare_release).with(build.build_number, build.version_name, true, anything, true).once
      end
    end

    context "when build is not found" do
      it "raises an exception" do
        build_not_found_error = Installations::Apple::AppStoreConnect::Error.new("error" => {"code" => "not_found", "resource" => "build"})
        allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise build_not_found_error })

        job = described_class.new
        job_id = SecureRandom.hex
        job.current_jid = job_id
        cache_key = "job_#{job_id}_retry_attempts"
        Rails.cache.write(cache_key, 9, expires_in: 7.days)

        expect { job.perform(submission.id, job_id) }.to raise_error(build_not_found_error)
        expect(submission.reload.preparing?).to be true
      end
    end

    it "schedules a retry with backoff when should_retry? is true and attempts are within the limit" do
      build_not_found_error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "build"}})
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise build_not_found_error })
      allow_any_instance_of(described_class).to receive(:should_retry?).and_return(true)

      job = described_class.new
      job_id = SecureRandom.hex
      job.current_jid = job_id
      cache_key = "job_#{job_id}_retry_attempts"
      Rails.cache.write(cache_key, 3, expires_in: 7.days)

      expect {
        job.perform(submission.id, job_id)
      }.to change { described_class.jobs.size }.by(1)

      enqueued_job = described_class.jobs.last
      expect(enqueued_job["args"]).to eq([submission.id, job_id])
      expect(enqueued_job["at"]).to be_within(1.second).of(1.minute.from_now.to_f)
      expect(submission.reload.preparing?).to be true
      expect(Rails.cache.read(cache_key)).to eq(4)
    end
  end
end
