# frozen_string_literal: true

require "rails_helper"

describe Accounts::User do
  describe ".onboard_via_email" do
    it "creates a new user with email-auth and an org-membership" do
      org = build(:organization)
      user = build(:user, organizations: [org])
      email_auth = build(:email_authentication, user: user)

      email_auth = described_class.onboard_via_email email_auth

      expect(email_auth).to be_persisted
      expect(email_auth.organizations.first).to eq(org)
      expect(email_auth.memberships.size).to eq(1)
      expect(email_auth.user.organizations.size).to eq(1)
    end

    context "when already exists" do
      it "adds an error if the user already exists" do
        existing_user = create(:user, :as_developer)
        existing_email_auth = create(:email_authentication, user: existing_user)
        new_org = build(:organization)
        new_user = build(:user, organizations: [new_org])
        new_email_auth = build(:email_authentication, user: new_user, email: existing_email_auth.email)

        new_email_auth = described_class.onboard_via_email new_email_auth

        expect(new_email_auth).not_to be_valid
        expect(new_email_auth).not_to be_persisted
      end

      it "organizations or memberships remain unchanged" do
        existing_user = create(:user, :as_developer)
        existing_email_auth = create(:email_authentication, user: existing_user)
        new_org = build(:organization)
        new_user = build(:user, organizations: [new_org])
        new_email_auth = build(:email_authentication, user: new_user, email: existing_email_auth.email)

        described_class.onboard_via_email new_email_auth

        expect(described_class.first.memberships.size).to eq(1)
        expect(described_class.first.organizations.size).to eq(1)
        expect(described_class.count).to eq(1)
      end
    end
  end
end
