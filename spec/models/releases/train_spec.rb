require "rails_helper"

describe Releases::Train do
  it "has a valid factory" do
    expect(create(:releases_train)).to be_valid
  end

  context "with draft mode" do
    let(:train) { create(:releases_train, :draft) }

    it "allows creating steps" do
      create(:releases_step, :with_deployment, train: train)
      expect(train.reload.steps.size).to be(1)
    end
  end

  describe "#activate!" do
    let(:train) { create(:releases_train, :draft) }

    it "disallows creating more than one release step" do
      build(:releases_step, :release, :with_deployment, train: train)
      build(:releases_step, :release, :with_deployment, train: train)

      expect { train.activate! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows creating multiple review steps" do
      create(:releases_step, :review, :with_deployment, train: train)
      create(:releases_step, :review, :with_deployment, train: train)
      create(:releases_step, :release, :with_deployment, train: train)

      expect(train.activate!).to be(true)
      expect(train.errors).to be_empty
      expect(train.reload.active?).to be(true)
    end
  end
end
