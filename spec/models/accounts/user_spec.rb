# frozen_string_literal: true

require "rails_helper"

describe Accounts::User do
  describe ".onboard!" do
    it "creates a new user and an org-membership" do
      org = build(:organization)
      user = build(:user, organizations: [org])

      user = described_class.onboard! user

      expect(user).to be_persisted
      expect(user.organizations.first).to eq(org)
      expect(user.memberships.size).to eq(1)
      expect(user.organizations.size).to eq(1)
    end

    it "attaches an error if the user already exists" do
      existing_user = create(:user, :as_developer)
      new_org = build(:organization)
      new_user = build(:user, email: existing_user.email, organizations: [new_org])

      user = described_class.onboard! new_user

      expect(user).not_to be_persisted
      expect(described_class.count).to eq(1)
      expect(described_class.first.memberships.size).to eq(1)
      expect(described_class.first.organizations.size).to eq(1)
    end
  end
end
