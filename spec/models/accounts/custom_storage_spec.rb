require "rails_helper"

describe Accounts::CustomStorage do
  let(:organization) { create(:organization) }

  describe "associations" do
    it "belongs to organization" do
      custom_storage = build(:accounts_custom_storage)
      expect(custom_storage.organization).to be_a(Accounts::Organization)
    end
  end

  describe "validations" do
    context "when all required fields are present" do
      let(:custom_storage) { build(:accounts_custom_storage, organization: organization) }

      it "is valid" do
        expect(custom_storage).to be_valid
      end
    end

    context "when bucket is missing" do
      let(:custom_storage) { build(:accounts_custom_storage, bucket: nil) }

      it "is invalid" do
        expect(custom_storage).not_to be_valid
        expect(custom_storage.errors[:bucket]).to include("can't be blank")
      end
    end

    context "when bucket_region is missing" do
      let(:custom_storage) { build(:accounts_custom_storage, bucket_region: nil) }

      it "is invalid" do
        expect(custom_storage).not_to be_valid
        expect(custom_storage.errors[:bucket_region]).to include("can't be blank")
      end
    end

    context "when service is missing" do
      let(:custom_storage) { build(:accounts_custom_storage, service: nil) }

      it "is invalid" do
        expect(custom_storage).not_to be_valid
        expect(custom_storage.errors[:service]).to include("can't be blank")
      end
    end

    context "when service is invalid" do
      let(:custom_storage) { build(:accounts_custom_storage, service: "invalid_service") }

      it "is invalid" do
        expect(custom_storage).not_to be_valid
        expect(custom_storage.errors[:service]).to include("is not included in the list")
      end
    end

    context "when organization already has a custom storage" do
      let(:duplicate_custom_storage) { build(:accounts_custom_storage, organization: organization) }

      it "is invalid" do
        _existing_custom_storage = create(:accounts_custom_storage, organization: organization)
        expect(duplicate_custom_storage).not_to be_valid
        expect(duplicate_custom_storage.errors[:organization]).to include("has already been taken")
      end
    end
  end

  describe "#service_name" do
    context "with google service" do
      let(:custom_storage) { build(:accounts_custom_storage, service: "google") }

      it "returns the correct service name" do
        expect(custom_storage.service_name).to eq("Google Cloud Storage")
      end
    end

    context "with google_india service" do
      let(:custom_storage) { build(:accounts_custom_storage, service: "google_india") }

      it "returns the correct service name" do
        expect(custom_storage.service_name).to eq("Google Cloud Storage")
      end
    end
  end

  describe "service normalization" do
    it "normalizes service to lowercase" do
      custom_storage = build(:accounts_custom_storage, service: "GOOGLE")
      custom_storage.valid?
      expect(custom_storage.service).to eq("google")
    end

    it "strips whitespace from service" do
      custom_storage = build(:accounts_custom_storage, service: " google ")
      custom_storage.valid?
      expect(custom_storage.service).to eq("google")
    end

    it "accepts mixed-case service because of normalization" do
      custom_storage = build(:accounts_custom_storage, service: "GoOgLe")
      expect(custom_storage).to be_valid
    end
  end

  describe "SERVICES constant" do
    it "contains expected services" do
      expect(Accounts::CustomStorage::SERVICES).to include(google: "Google Cloud Storage", google_india: "Google Cloud Storage")
    end
  end
end
