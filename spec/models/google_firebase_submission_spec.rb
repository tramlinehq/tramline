require "rails_helper"

describe GoogleFirebaseSubmission do
  before do
    allow(Coordinators::Signals).to receive(:internal_release_finished!)
  end

  it "has a valid factory" do
    expect(create(:google_firebase_submission)).to be_valid
  end

  describe "#trigger!" do
    let(:submission) { create(:google_firebase_submission) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }
    let(:release_info) {
      {
        build_version: "471280959",
        create_time: "2024-07-05T23:51:56.539088Z",
        display_version: "10.31.0",
        firebase_console_uri: Faker::Internet.url,
        name: Faker::String.random(length: 10),
        release_notes: {text: "NOTES"}
      }
    }
    let(:release_info_obj) { GoogleFirebaseIntegration::ReleaseInfo.new(release_info, GoogleFirebaseIntegration::BUILD_TRANSFORMATIONS) }

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
      expect(submission.store_link).to eq(release_info[:firebase_console_uri])
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
    let(:parent_release) { create(:internal_release) }
    let(:release_platform_run) { parent_release.release_platform_run }
    let(:workflow_run) { create(:workflow_run, :finished, triggering_release: parent_release) }
    let(:build) { create(:build, :with_artifact, workflow_run:) }
    let(:submission) { create(:google_firebase_submission, :preprocessing, build:, release_platform_run:, parent_release:) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
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
      expect(expected_job).not_to have_received(:perform_async).with(submission.id, result)
    end
  end

  describe "#update_upload_status!" do
    let(:parent_release) { create(:internal_release) }
    let(:release_platform_run) { parent_release.release_platform_run }
    let(:workflow_run) { create(:workflow_run, :finished, triggering_release: parent_release) }
    let(:build) { create(:build, :with_artifact, workflow_run:) }
    let(:submission) { create(:google_firebase_submission, :preprocessing, build:, release_platform_run:, parent_release:) }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }
    let(:op_info) {
      {
        done: true,
        response: {
          result: "SUCCESS",
          release: {
            name: Faker::String.random(length: 10),
            firebaseConsoleUri: Faker::Internet.url
          }
        }
      }
    }
    let(:op_info_obj) { GoogleFirebaseIntegration::ReleaseOpInfo.new(op_info) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
    end

    it "prepares and updates the submission" do
      expected_job = StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob
      allow(providable_dbl).to receive(:get_upload_status).and_return(GitHub::Result.new { op_info_obj })
      allow(expected_job).to receive(:perform_later)

      submission.update_upload_status!("op_name")
      submission.reload

      expect(submission.preparing?).to be(true)
      expect(submission.store_link).to eq(op_info[:response][:release][:firebaseConsoleUri])
      expect(expected_job).to have_received(:perform_later).with(submission.id, op_info[:response][:release][:name]).once
    end

    it "fails if upload check fails" do
      expected_job = StoreSubmissions::GoogleFirebase::UpdateBuildNotesJob
      allow(providable_dbl).to receive(:get_upload_status).and_return(GitHub::Result.new { raise })
      allow(expected_job).to receive(:perform_later)

      submission.update_upload_status!("op_name")
      submission.reload

      expect(submission.failed?).to be(true)
      expect(expected_job).not_to have_received(:perform_later)
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
      release_info_obj = GoogleFirebaseIntegration::ReleaseOpInfo.new(release_info)
      allow(providable_dbl).to receive(:get_upload_status).and_return(GitHub::Result.new { release_info_obj })

      expect {
        submission.update_upload_status!("op_name")
      }.to raise_error(GoogleFirebaseSubmission::UploadNotComplete)
    end
  end

  describe "#prepare_release!" do
    let(:workflow_run) { create(:workflow_run, :finished) }
    let(:build) { create(:build, :with_artifact, workflow_run:, commit: workflow_run.commit) }
    let(:release_platform_run) { build.release_platform_run }
    let(:internal_release) {
      create(:internal_release,
        release_platform_run:,
        commit: workflow_run.commit,
        triggered_workflow_run: workflow_run,
        config: {
          submissions: [
            {number: 1,
             submission_type: "GoogleFirebaseSubmission",
             submission_config: {id: :internal, name: "internal testing"}}
          ]
        })
    }
    let(:submission) {
      create(:google_firebase_submission, :with_store_release, :preparing,
        build:, release_platform_run:, parent_release: internal_release)
    }
    let(:providable_dbl) { instance_double(GoogleFirebaseIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
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
