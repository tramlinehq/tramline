require "rails_helper"

RSpec.describe Releases::CopyPreviousApprovalsJob do
  let(:release) { create(:release) }
  let(:release_id) { release.id }

  describe "#perform" do
    before do
      allow(release).to receive(:copy_previous_approvals).and_wrap_original do |_m, *_args|
        create(:approval_item, release: release)
      end

      allow(Release).to receive(:find_by).with(id: release_id).and_return(release)
    end

    it "adds approval items to the release if none exist" do
      expect(release.approval_items).to be_empty

      described_class.perform_now(release_id)

      release.reload
      expect(release.approval_items.count).to eq(1)
      expect(release.approval_items).to all(be_a(ApprovalItem))
    end

    it "performs the job successfully without errors" do
      expect { described_class.perform_now(release_id) }.not_to raise_error
    end

    context "when release is not found" do
      before do
        allow(Release).to receive(:find_by).with(id: release_id).and_return(nil)
      end

      it "logs an error if release is not found" do
        allow(Rails.logger).to receive(:error)

        described_class.perform_now(release_id)

        expect(Rails.logger).to have_received(:error).with("Release with ID #{release_id} not found")
      end
    end
  end
end
