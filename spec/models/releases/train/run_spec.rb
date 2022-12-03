require "rails_helper"

RSpec.describe Releases::Train::Run, type: :model do
  it "has a valid factory" do
    expect(create(:releases_train_run)).to be_valid
  end

  describe "#next_step" do
    subject { create(:releases_train_run) }

    let(:steps) { create_list(:releases_step, 5, train: subject.train) }

    it "returns next step" do
      expect(subject.next_step).to be_nil
    end
  end

  describe "#startable_step?" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, train: active_train) }

    it "first step can be started if there are no step runs" do
      train_run = create(:releases_train_run, train: active_train)

      expect(train_run.startable_step?(steps.first)).to be(true)
      expect(train_run.startable_step?(steps.second)).to be(false)
    end

    it "next step can be started after finishing previous step" do
      train_run = create(:releases_train_run, train: active_train)
      create(:releases_step_run, step: steps.first, status: "success", train_run: train_run)

      expect(train_run.startable_step?(steps.first)).to be(false)
      expect(train_run.startable_step?(steps.second)).to be(true)
    end
  end
end
