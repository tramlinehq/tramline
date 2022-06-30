require "rails_helper"

RSpec.describe Releases::Train::Run, type: :model do
  it "has valid spec" do
    expect(FactoryBot.create(:releases_train_run)).to be_valid
  end
end
