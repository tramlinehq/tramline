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

  describe ".add_via_email" do
    let(:email) { Faker::Internet.email }

    it "adds the user to the organization" do
      user = create(:user, :as_developer, unique_authn_id: email)
      create(:email_authentication, email:, user:)
      invite = create(:invite, email:)

      described_class.add_via_email(invite)

      expect(user.organizations.reload).to include(invite.organization)
    end
  end

  describe ".start_sign_in_via_sso" do
    it "returns nil if the organization is not found" do
      expect(described_class.start_sign_in_via_sso("nothing@exists.com").nil?).to be true
    end

    it "starts sign-in if the user exists for the sso organization" do
      allow(Accounts::SsoAuthentication).to receive(:start_sign_in)
      organization = create(:organization, :with_sso, sso_domains: ["tramline.app"])

      email = "something@tramline.app"
      sso_auth = create(:sso_authentication, email:)
      user = create(:user)
      create(:membership, organization:, user:)
      user.sso_authentications << sso_auth

      described_class.start_sign_in_via_sso(email)

      expect(Accounts::SsoAuthentication).to have_received(:start_sign_in).with(organization.sso_tenant_id)
    end

    it "starts sign in if the invite exists for the sso organization" do
      allow(Accounts::SsoAuthentication).to receive(:start_sign_in)
      email = "something@tramline.app"
      organization = create(:organization, :with_sso, sso_domains: ["tramline.app"])
      create(:invite, organization:, email:)

      described_class.start_sign_in_via_sso(email)

      expect(Accounts::SsoAuthentication).to have_received(:start_sign_in).with(organization.sso_tenant_id)
    end
  end

  describe ".finish_sign_in_via_sso" do
    let(:ip) { "127.0.0.1" }
    let(:email) { "something@tramline.app" }
    let(:valid_sso_result) { GitHub::Result.new { {user_email: email, user_full_name: "User Name", login_id: "unique_id", user_preferred_name: "name"} } }

    before do
      allow(Accounts::SsoAuthentication).to receive(:finish_sign_in).and_return(valid_sso_result)
    end

    it "returns nil if the organization is not found" do
      expect(described_class.finish_sign_in_via_sso("code", ip).nil?).to be true
    end

    it "returns nil if the sso finish sign in result is not ok" do
      allow(Accounts::SsoAuthentication).to receive(:finish_sign_in).and_return(GitHub::Result.new { GitHub::Result::Error.new("error") })
      create(:organization, :with_sso, sso_domains: ["tramline.app"])

      expect(described_class.finish_sign_in_via_sso("code", ip).nil?).to be true
    end

    it "returns nil if the user is not found" do
      create(:organization, :with_sso, sso_domains: ["tramline.app"])
      expect(described_class.finish_sign_in_via_sso("code", "").nil?).to be true
    end

    it "updates the sso tracking details if user exists" do
      organization = create(:organization, :with_sso, sso_domains: ["tramline.app"])
      sso_auth = create(:sso_authentication, email:)
      user = create(:user)
      create(:membership, organization: organization, user:)
      user.sso_authentications << sso_auth

      actual_result = described_class.finish_sign_in_via_sso("code", ip)

      expect(sso_auth.reload.sign_in_count).to eq(1)
      expect(sso_auth.reload.current_sign_in_at).not_to be_nil
      expect(sso_auth.reload.current_sign_in_ip).to eq(ip)
      expect(actual_result).to eq(valid_sso_result.value!)
    end

    it "creates the user with sso auth if invite exists" do
      organization = create(:organization, :with_sso, sso_domains: ["tramline.app"])
      invite = create(:invite, email:, organization:)

      expect { described_class.finish_sign_in_via_sso("code", ip) }.to change(Accounts::SsoAuthentication, :count).by(1)

      created_sso_auth = Accounts::SsoAuthentication.first
      expect(created_sso_auth.email).to eq(email)
      expect(created_sso_auth.user).to eq(invite.reload.recipient)
    end
  end
end
