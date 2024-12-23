require "rails_helper"

describe Releases::CopyPreviousApprovalsJob do
  let(:release) { create(:release) }
  let(:train) { release.train }
  let(:previous_release) { create(:release, :finished, train:, completed_at: release.created_at - 1.day) }

  describe "#perform" do
    before do
      create(:approval_item, release: previous_release)
    end

    it "adds approval items to the release if none exist" do
      expect(release.approval_items).to be_empty

      described_class.perform_now(release.id)
      release.reload

      expect(release.approval_items.size).to eq(1)
    end

    it "performs the job successfully without errors" do
      expect { described_class.perform_now(release.id) }.not_to raise_error
    end

    context "when release is not found" do
      it "logs an error if release is not found" do
        erroneous_release_id = Faker::Number.number
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(erroneous_release_id)

        expect(Rails.logger).to have_received(:error).with("Release with ID #{erroneous_release_id} not found")
      end
    end
  end
end
