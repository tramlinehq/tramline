require "rails_helper"

describe Accounts::UsersController do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user) }
  let(:current_user_email) { current_user.email }
  let(:member_email) { Faker::Internet.email }
  let(:member) { create(:user, :with_email_authentication, unique_authn_id: member_email) }

  before do
    allow(controller).to receive_messages(current_user: current_user, current_organization: organization)
  end

  describe "PATCH #update_user_role" do
    context "when the user attempts to change their own role" do
      it "does not allow the user to change their own role" do
        patch :update_user_role, params: {email: current_user_email, role: "owner"}

        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("User #{current_user_email} cannot change their own role.")
      end
    end

    context "when the user is found and role is updated successfully" do
      before do
        create(:membership, user: member, organization: organization, role: "developer")
        patch :update_user_role, params: {email: member.email, role: "owner"}
      end

      it "updates the user's role" do
        membership = organization.memberships.find_by(user: member)
        expect(membership.role).to eq("owner")
      end

      it "redirects to the teams path with a success notice" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:notice]).to eq("#{member.email} role was successfully updated to owner")
      end
    end

    context "when the user is sso user" do
      let(:member_email) { "sso_user@tramline.app" }
      let(:member) { create(:user, unique_authn_id: member_email) }

      before do
        organization.update!(sso: true, sso_domains: ["tramline.app"])
        sso_auth = create(:sso_authentication, email: member_email)
        create(:membership, organization: organization, user: member, role: "developer")
        member.sso_authentications << sso_auth

        patch :update_user_role, params: {email: member.email, role: "owner"}
      end

      it "updates the user's role" do
        membership = organization.memberships.find_by(user: member)
        expect(membership.role).to eq("owner")
      end

      it "redirects to the teams path with a success notice" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:notice]).to eq("#{member.email} role was successfully updated to owner")
      end
    end

    context "when the user is found but membership is not found" do
      it "redirects to the teams path with an alert" do
        patch :update_user_role, params: {email: member.email, role: "owner"}

        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("User #{member.email} memberships not found")
      end
    end

    context "when the user is not found" do
      it "redirects to the teams path with an alert" do
        patch :update_user_role, params: {email: "invalid_email@example.com", role: "owner"}

        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("User invalid_email@example.com not found")
      end
    end
  end
end
