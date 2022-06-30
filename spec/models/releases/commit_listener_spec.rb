require "rails_helper"

RSpec.describe Releases::CommitListener, type: :model do
  it "it has valid factoy" do
    expect(FactoryBot.create(:releases_commit_listener)).to be_valid
  end
end
