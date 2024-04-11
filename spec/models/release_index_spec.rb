require "rails_helper"

describe ReleaseIndex do
  it "has a valid factory" do
    expect(create(:release_index)).to be_valid
  end

  context "for tolerance range" do
    it "is invalid for a tolerance range less than 0" do
      index = build(:release_index, tolerable_range: -0.5..0.5)
      expect(index).not_to be_valid
    end

    it "is invalid for a tolerance range greater than 1" do
      index = build(:release_index, tolerable_range: 0.5..1.5)
      expect(index).not_to be_valid
    end

    it "is valid for a tolerance range between 0 and 1" do
      index = build(:release_index, tolerable_range: 0.1..0.9)
      expect(index).to be_valid
    end
  end
end
