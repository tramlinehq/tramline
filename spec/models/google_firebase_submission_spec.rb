require "rails_helper"

describe GoogleFirebaseSubmission do
  it "has a valid factory" do
    expect(create(:google_firebase_submission)).to be_valid
  end
end
