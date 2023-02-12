require "rails_helper"

describe SignOffGroup do
  it "has a valid factory" do
    expect(build(:sign_off_group)).to be_valid
  end
end
