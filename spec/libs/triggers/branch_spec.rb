# frozen_string_literal: true

require "rails_helper"

describe Triggers::Branch do
  describe ".call" do
    let(:release) { create(:release) }
    let(:train) { release.train }
    let(:source_branch) { "source" }
    let(:new_branch) { "new" }
    let(:create_branch_fixture) { JSON.parse(File.read("spec/fixtures/github/create_branch.json")).to_h.with_indifferent_access }

    it "creates the branch and returns the branch data" do
      allow(train).to receive(:create_branch!).and_return(create_branch_fixture)
      allow(release).to receive(:event_stamp_now!)

      result = described_class.call(release, source_branch, new_branch, :branch, anything, anything)

      expect(result.ok?).to be(true)
      expect(result.value!).to match(create_branch_fixture)
    end

    it "event stamps on success" do
      allow(train).to receive(:create_branch!).and_return(create_branch_fixture)
      allow(release).to receive(:event_stamp_now!)

      described_class.call(release, source_branch, new_branch, :branch, anything, anything)

      expect(release).to have_received(:event_stamp_now!).with(anything).once
    end

    it "returns a non-ok result when branch creation fails" do
      allow(train).to receive(:create_branch!).and_raise(Installations::Error.new("Failed to create branch", reason: :unknown_failure))

      result = described_class.call(release, source_branch, new_branch, :branch, anything, anything)

      expect(result.ok?).to be(false)
      expect(result.error).to be_a(Triggers::Branch::BranchCreateError)
      expect(result.error.message).to eq("Could not create branch #{new_branch} from #{source_branch}")
    end

    it "gracefully handles error when branch already exists" do
      allow(train).to receive(:create_branch!).and_raise(Installations::Error.new("Branch already exists", reason: :tag_reference_already_exists))

      result = described_class.call(release, source_branch, new_branch, :branch, anything, anything)

      expect(result.ok?).to be(true)
      expect(result.value!).to be_nil
    end
  end
end
