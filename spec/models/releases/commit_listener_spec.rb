require "rails_helper"

RSpec.describe Releases::CommitListener, type: :model do
  it "has valid factory" do
    expect(create(:releases_commit_listener)).to be_valid
  end
end
