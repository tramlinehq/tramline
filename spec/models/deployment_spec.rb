require "rails_helper"

describe Deployment, type: :model do
  it "has a valid factory" do
    expect(create(:deployment, :with_step)).to be_valid
  end

  describe "#create" do
    it "adds incremented deployment numbers" do
      step = create(:releases_step, :with_deployment)
      d1 = create(:deployment, step: step)
      d2 = create(:deployment, step: step)

      expect(d1.deployment_number).to eq(2)
      expect(d2.deployment_number).to eq(3)
    end
  end
end
