require "rails_helper"

RSpec.describe Releases::Step, type: :model do
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
  end
end
