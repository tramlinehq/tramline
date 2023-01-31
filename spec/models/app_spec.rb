require "rails_helper"

describe App, type: :model do
  it "has a valid factory" do
    expect(create(:app, :android)).to be_valid
    expect(create(:app, :ios)).to be_valid
  end
end
