require "rails_helper"

describe Webhooks::Bitbucket::Push do
  let(:train) { create(:train) }

  context "when a branch is pushed" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/bitbucket/push.json")) }
    let(:push) { described_class.new(payload, train) }

    it "is a valid branch push" do
      expect(push.valid_tag?).to be(false)
      expect(push.valid_branch?).to be(true)
      expect(push.valid_head_commit?).to be(true)
      expect(push.branch_name).to eq("r/bb-train/2024-09-06-1")
    end
  end

  context "when a branch is deleted" do
    let(:payload) do
      {
        "push" => {"changes" => [{"old" => {"type" => "branch", "name" => "r/bb-train/2024-09-06-1"}, "new" => nil, "closed" => true, "created" => false, "forced" => false}]},
        "repository" => {"full_name" => "tramline/ueno", "name" => "ueno"}
      }
    end
    let(:push) { described_class.new(payload, train) }

    it "is neither a tag nor a branch push and has no head commit" do
      expect(push.valid_tag?).to be(false)
      expect(push.valid_branch?).to be(false)
      expect(push.valid_head_commit?).to be(false)
      expect(push.branch_name).to be_nil
    end
  end
end
