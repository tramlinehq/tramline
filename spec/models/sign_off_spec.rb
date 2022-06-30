require "rails_helper"

RSpec.describe SignOff, type: :model do
  it "Has valid factory" do
    expect(FactoryBot.build(:sign_off)).to be_valid
  end
end
