require "rails_helper"

describe Accounts::UsersController do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user) }
  let(:current_user_email) { current_user.email }

  let!(:member_email) { Faker::Internet.email }
  let!(:member) { create(:user, unique_authn_id: member_email) }

  let(:membership) { create(:membership, user: member, organization: organization, role: "developer") }

  before do
    allow(controller).to receive_messages(current_user: current_user, current_organization: organization)
  end

  describe "PATCH #update_user_role" do
    context "when the user attempts to change their own role" do
      before do
        allow(Accounts::User).to receive(:find_via_email).with(current_user_email).and_return(current_user)
        patch :update_user_role, params: {email: current_user_email, role: "owner"}
      end

      it "does not allow the user to change their own role" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("User #{current_user_email} cannot change their own role.")
      end
    end

    context "when the user is found and role is updated successfully" do
      before do
        allow(Accounts::User).to receive(:find_via_email).with(member.email).and_return(member)
        allow(member.memberships).to receive(:find_by).with(organization: organization).and_return(membership)
        patch :update_user_role, params: {email: member.email, role: "owner"}
      end

      it "updates the user's role" do
        expect(membership.reload.role).to eq("owner")
      end

      it "redirects to the teams path with a success notice" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:notice]).to eq("#{member.email} role was successfully updated to owner")
      end
    end

    context "when the user is found but membership is not found" do
      before do
        allow(Accounts::User).to receive(:find_via_email).with(member.email).and_return(member)
        allow(member.memberships).to receive(:find_by).with(organization: organization).and_return(nil)
        patch :update_user_role, params: {email: member.email, role: "owner"}
      end

      it "redirects to the teams path with an alert" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("User #{member.email} memberships not found")
      end
    end

    context "when the user is not found" do
      before do
        allow(Accounts::User).to receive(:find_via_email).with(member.email).and_return(nil)
        patch :update_user_role, params: {email: member.email, role: "owner"}
      end

      it "redirects to the teams path with an alert" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("User #{member.email} not found")
      end
    end

    context "when the membership update fails" do
      before do
        allow(Accounts::User).to receive(:find_via_email).with(member.email).and_return(member)
        allow(member.memberships).to receive(:find_by).with(organization: organization).and_return(membership)
        allow(membership).to receive(:update).and_return(false)
        patch :update_user_role, params: {email: member.email, role: "owner"}
      end

      it "redirects to the teams path with an alert" do
        expect(response).to redirect_to(accounts_organization_teams_path(organization))
        expect(flash[:alert]).to eq("Updating #{member.email} role failed")
      end
    end
  end
end
