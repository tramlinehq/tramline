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

      described_class.new.perform(release.id)
      release.reload

      expect(release.approval_items.size).to eq(1)
    end

    it "performs the job successfully without errors" do
      expect { described_class.new.perform(release.id) }.not_to raise_error
    end

    context "when release is not found" do
      it "raises an error if release is not found" do
        erroneous_release_id = Faker::Number.number
        expect { described_class.new.perform(erroneous_release_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
