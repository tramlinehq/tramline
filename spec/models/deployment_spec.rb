require "rails_helper"

RSpec.describe Deployment, type: :model do
  it "has valid spec" do
    expect(create(:deployment)).to be_valid
  end
end
