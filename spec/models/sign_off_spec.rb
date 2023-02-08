require "rails_helper"

describe SignOff do
  it "has a valid factory" do
    expect(build(:sign_off)).to be_valid
  end
end
