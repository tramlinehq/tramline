require "rails_helper"

describe SignOffGroupMembership do
  it "has a valid factory" do
    expect(build(:sign_off_group_membership)).to be_valid
  end
end
