require "rails_helper"

RSpec.describe SignOff, type: :model do
  it "has a valid factory" do
    expect(build(:sign_off)).to be_valid
  end
end
