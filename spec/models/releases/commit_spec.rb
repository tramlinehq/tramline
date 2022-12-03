require "rails_helper"

RSpec.describe Releases::Commit, type: :model do
  it "has valid factory" do
    expect(create(:releases_commit)).to be_valid
  end
end
