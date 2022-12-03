require "rails_helper"

RSpec.describe SignOffGroup, type: :model do
  it "has a valid factory" do
    expect(FactoryBot.build(:sign_off_group)).to be_valid
  end
end
