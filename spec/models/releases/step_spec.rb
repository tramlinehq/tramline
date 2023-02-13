require "rails_helper"

describe Releases::Step do
  it "has valid factory" do
    expect(create(:releases_step, :with_deployment)).to be_valid
  end

  describe "#next" do
    let(:train) { create(:releases_train) }
    let(:steps) { create_list(:releases_step, 5, :with_deployment, train: train) }

    it "returns next element" do
      first_step = steps.first
      expect(first_step.next).to be_eql(steps.second)
    end

    it "returns nil for final element" do
      expect(steps.last.next).to be_nil
    end
  end

  describe "#create" do
    it "saves deployments along with it" do
      step = build(:releases_step)
      step.deployments = build_list(:deployment, 2)
      step.save!

      expect(step.reload.deployments.size).to eq(2)
    end

    it "adds incremented deployment numbers to created deployments" do
      step = build(:releases_step)
      step.deployments = build_list(:deployment, 2)
      step.save!

      expect(step.reload.deployments.pluck(:deployment_number)).to contain_exactly(1, 2)
    end

    context "when train in draft mode" do
      let(:train) { create(:releases_train, :draft) }

      it "create is allowed" do
        create(:releases_step, :with_deployment, train: train)
        expect(train.reload.steps.size).to be(1)
      end
    end

    context "when train in active mode" do
      let(:train) { create(:releases_train, :active) }

      it "create is disallowed" do
        expect(build(:releases_step, :with_deployment, train: train)).not_to be_valid
      end
    end
  end
end
