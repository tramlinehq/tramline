require "rails_helper"

RSpec.describe Releases::Step, type: :model do
  it "has valid spec" do
    expect(FactoryBot.create(:releases_step)).to be_valid
  end

  describe "#next" do
    let(:train) { FactoryBot.create(:releases_train) }
    let(:steps) { FactoryBot.create_list(:releases_step, 5, train: train) }

    it "returns next element" do
      first_step = steps.first
      expect(first_step.next).to be_eql(steps.second)
    end

    it "returns nil for final element" do
      expect(steps.last.next).to be_nil
    end
  end
end
