require "rails_helper"

describe ReleasePlatform do
  it "has a valid factory" do
    expect(create(:release_platform)).to be_valid
  end
end
