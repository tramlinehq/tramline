require "rails_helper"

RSpec.describe Releases::Train::Run, type: :model do
  it "has valid spec" do
    expect(create(:releases_train_run)).to be_valid
  end

  describe ".next_step" do
    subject { create(:releases_train_run) }
    let(:steps) { create_list(:releases_step, 5, train: subject.train) }

    it "returns next step" do
      expect(subject.next_step).to be_nil
    end
  end
end
