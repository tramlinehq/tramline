require "rails_helper"

RSpec.describe Releases::Step, type: :model do
  it "has valid spec" do
    expect(FactoryBot.create(:releases_step)).to be_valid
  end

  describe "#next" do
    let(:train) { FactoryBot.create(:releases_train) }
    let(:steps) { FactoryBot.create_list(:releases_step, 5, train: train) }

    it "retuns next element" do
      first_step = steps.first
      expect(first_step.next).to be_eql(steps.second)
    end

    it "returns nil for final element" do
      expect(steps.last.next).to be_nil
    end
  end

  describe "#startable?" do
    let(:train) { FactoryBot.create(:releases_train) }
    let(:steps) { FactoryBot.create_list(:releases_step, 5, train: train) }

    it "first step can be started if there are no step runs" do
      expect(steps.first).to be_startable
    end

    it "second step can be started after finishing first step" do
      second_step = steps.second
      release = FactoryBot.create(:releases_train_run, train:)
      FactoryBot.create(:releases_step_run, step: steps.first, status: "success", train_run: release)
      expect(second_step).to be_startable
    end
  end
end
