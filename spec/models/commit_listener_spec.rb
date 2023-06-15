require "rails_helper"

describe CommitListener do
  it "has valid factory" do
    expect(create(:commit_listener)).to be_valid
  end
end
