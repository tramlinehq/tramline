require "rails_helper"

describe GoogleFirebaseSubmission do
  it "has a valid factory" do
    expect(create(:google_firebase_submission)).to be_valid
  end

  describe "#trigger!" do
    let(:submission) { create(:google_firebase_submission) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }
    let(:release_info) {
      {
        response: {
          result: "SUCCESS",
          release: {
            firebaseConsoleUri: Faker::Internet.url
          }
        }
      }
    }
    let(:release_info_obj) { GoogleFirebaseIntegration::ReleaseInfo.new(release_info) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "prepares and updates the submission if build already in store" do
      expected_job = StoreSubmissions::GoogleFirebase::PrepareForReleaseJob
      allow(providable_dbl).to receive(:find_build_by_build_number).and_return(GitHub::Result.new { release_info_obj })
      allow(expected_job).to receive(:perform_later)

      submission.trigger!
      submission.reload

      expect(submission.preparing?).to be(true)
      expect(submission.store_link).to eq(release_info[:response][:release][:firebaseConsoleUri])
      expect(expected_job).to have_received(:perform_later).with(submission.id).once
    end

    it "preprocesses the submission if build not in store" do
      expected_job = StoreSubmissions::GoogleFirebase::UploadJob
      allow(providable_dbl).to receive(:find_build_by_build_number).and_return(GitHub::Result.new { raise })
      allow(expected_job).to receive(:perform_later)

      submission.trigger!
      submission.reload

      expect(submission.preprocessing?).to be(true)
      expect(submission.store_link).to be_nil
      expect(expected_job).to have_received(:perform_later).with(submission.id).once
    end
  end

  describe "#upload_build!" do
    let(:build) { create(:build, :with_artifact) }
    let(:release_platform_run) { build.release_platform_run }
    let(:submission) { create(:google_firebase_submission, :preprocessing, build:, release_platform_run:) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "starts the upload" do
      expected_job = StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob
      result = 1
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new { result })
      allow(expected_job).to receive(:perform_async)

      submission.upload_build!
      expect(expected_job).to have_received(:perform_async).with(submission.id, result).once
    end

    it "marks failure if upload fails" do
      expected_job = StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob
      result = 1
      error = {
        "error" => {
          "status" => "PERMISSION_DENIED",
          "code" => 403,
          "message" => "The caller does not have permission"
        }
      }
      client_error = Google::Apis::ClientError.new("Error", body: error.to_json)
      error_obj = Installations::Google::Firebase::Error.new(client_error)
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new { raise error_obj })
      allow(expected_job).to receive(:perform_async)

      submission.upload_build!
      expect(submission.failed?).to be(true)
      expect(expected_job).to_not have_received(:perform_async).with(submission.id, result)
    end
  end

  describe "#update_upload_status!" do
    let(:build) { create(:build, :with_artifact) }
    let(:release_platform_run) { build.release_platform_run }
    let(:submission) { create(:google_firebase_submission, :preprocessing, build:, release_platform_run:) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }
    let(:release_info) {
      {
        done: true,
        response: {
          result: "SUCCESS",
          release: {
            firebaseConsoleUri: Faker::Internet.url
          }
        }
      }
    }
    let(:release_info_obj) { GoogleFirebaseIntegration::ReleaseInfo.new(release_info) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "prepares and updates the submission" do
      expected_job = StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob
      allow(providable_dbl).to receive(:get_upload_status).and_return(GitHub::Result.new { release_info_obj })
      allow(expected_job).to receive(:perform_later)

      submission.update_upload_status!("op_name")
      submission.reload

      expect(submission.preparing?).to be(true)
      expect(submission.store_link).to eq(release_info[:response][:release][:firebaseConsoleUri])
      expect(expected_job).to have_received(:perform_later).with(submission.id, release_info_obj.release).once
    end

    it "fails if upload check fails" do
      expected_job = StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob
      allow(providable_dbl).to receive(:get_upload_status).and_return(GitHub::Result.new { raise })
      allow(expected_job).to receive(:perform_later)

      submission.update_upload_status!("op_name")
      submission.reload

      expect(submission.failed?).to be(true)
      expect(expected_job).to_not have_received(:perform_later)
    end

    it "throws up if upload is not complete" do
      release_info = {
        done: false,
        response: {
          result: "SUCCESS",
          release: {
            firebaseConsoleUri: Faker::Internet.url
          }
        }
      }
      release_info_obj = GoogleFirebaseIntegration::ReleaseInfo.new(release_info)
      allow(providable_dbl).to receive(:get_upload_status).and_return(GitHub::Result.new { release_info_obj })

      expect {
        submission.update_upload_status!("op_name")
      }.to raise_error(GoogleFirebaseSubmission::UploadNotComplete)
    end
  end

  describe "#prepare_release!" do
    let(:build) { create(:build, :with_artifact) }
    let(:release_platform_run) { build.release_platform_run }
    let(:submission) { create(:google_firebase_submission, :with_store_release, :preparing, build:, release_platform_run:) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "finishes the release" do
      allow(providable_dbl).to receive(:release).and_return(GitHub::Result.new)

      submission.prepare_for_release!

      expect(submission.finished?).to be(true)
    end

    it "fails if release fails" do
      allow(providable_dbl).to receive(:release).and_return(GitHub::Result.new { raise })

      submission.prepare_for_release!

      expect(submission.finished?).to be(false)
    end
  end
end
