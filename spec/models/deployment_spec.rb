require "rails_helper"

RSpec.describe Deployment, type: :model do
  it "has valid spec" do
    expect(create(:deployment)).to be_valid
  end

  describe "#create" do
    it "adds incremented deployment numbers" do
      step = create(:releases_step)
      d1 = create(:deployment, step: step)
      d2 = create(:deployment, step: step)

      expect(d1.deployment_number).to eq(1)
      expect(d2.deployment_number).to eq(2)
    end
  end
end
