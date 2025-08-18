require "rails_helper"

RSpec.describe Accounts::CustomStorage do
  describe "associations" do
    it { is_expected.to belong_to(:organization).class_name("Accounts::Organization") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:bucket) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:credentials) }

    it "is not valid with invalid credentials" do
      organization = create(:organization)
      custom_storage = build(:accounts_custom_storage, organization: organization, credentials: "invalid")
      expect(custom_storage).not_to be_valid
      expect(custom_storage.errors[:credentials]).to include("must be a valid JSON object")
    end
  end
end
