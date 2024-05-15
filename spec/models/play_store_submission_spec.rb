require "rails_helper"

describe PlayStoreSubmission do
  it "has a valid factory" do
    expect(create(:play_store_submission)).to be_valid
  end

  describe ".start_release!" do
    let(:build) { create(:build) }
    let(:submission) { create(:play_store_submission, :preparing, build:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
    end

    it "creates draft release" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      submission.prepare_for_release!
      expect(providable_dbl).to have_received(:create_draft_release)
        .with("production",
          build.build_number,
          build.version_name,
          [{language: "en-US",
            text: "The latest version contains bug fixes and performance improvements."}])
    end

    it "marks the submission as prepared" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      expect { submission.prepare_for_release! }.to change(submission, :prepared?)
    end

    it "marks the submission as failed with manual action required when release fails due to app review rejection" do
      error_body = {"error" => {"status" => "INVALID_ARGUMENT",
                                "code" => 400,
                                "message" => "Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true. Once committed, the changes in this edit can be sent for review from the Google Play Console UI"}}
      error = Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new { raise Installations::Google::PlayDeveloper::Error.new(error) })
      expect { submission.prepare_for_release! }.to change(submission, :failed_with_action_required?)
    end
  end
end
