require 'rails_helper'

RSpec.describe Accounts::CustomStorage, type: :model do
  describe "associations" do
    it { should belong_to(:organization).class_name("Accounts::Organization") }
  end

  describe "validations" do
    it { should validate_presence_of(:bucket) }
    it { should validate_presence_of(:project_id) }
    it { should validate_presence_of(:credentials) }

    it "is not valid with invalid credentials" do
      organization = create(:organization)
      custom_storage = build(:accounts_custom_storage, organization: organization, credentials: "invalid")
      expect(custom_storage).not_to be_valid
      expect(custom_storage.errors[:credentials]).to include("must be a valid JSON object")
    end
  end
end
