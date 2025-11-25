require "rails_helper"

describe "Accounts::Users" do
  describe "PATCH /accounts/user/update_user_role" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, :with_email_authentication) }
    let(:member) { create(:user, :with_email_authentication) }

    describe "access control" do
      context "when user is an owner" do
        before do
          create(:membership, user: user, organization:, role: :owner)
          sign_in user.email_authentication
        end

        it "does not allow an owner to change another owner's role" do
          membership = create(:membership, user: member, organization:, role: :owner)

          expect do
            patch update_user_role_accounts_user_path,
              params: {email: member.email, role: :developer}
          end.not_to change { membership.reload.role }

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:alert]).to eq("You don't have permission to edit this member's role")
        end

        it "allows an owner to change a developer's role" do
          membership = create(:membership, user: member, organization:, role: :developer)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :owner}
          end.to change { membership.reload.role }.from("developer").to("owner")

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:notice]).to eq("#{member.email} role was successfully updated to owner")
        end

        it "allows an owner to change a viewer's role" do
          membership = create(:membership, user: member, organization:, role: :viewer)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :developer}
          end.to change { membership.reload.role }.from("viewer").to("developer")

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:notice]).to eq("#{member.email} role was successfully updated to developer")
        end
      end

      context "when user is a developer" do
        before do
          create(:membership, user: user, organization:, role: :developer)
          sign_in user.email_authentication
        end

        it "does not allow a developer to change an owner's role" do
          membership = create(:membership, user: member, organization:, role: :owner)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :viewer}
          end.not_to change { membership.reload.role }

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:alert]).to eq("You don't have permission to edit this member's role")
        end

        it "does not allow a developer to change another developer's role" do
          membership = create(:membership, user: member, organization:, role: :developer)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :viewer}
          end.not_to change { membership.reload.role }

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:alert]).to eq("You don't have permission to edit this member's role")
        end

        it "allows a developer to change a viewer's role" do
          membership = create(:membership, user: member, organization:, role: :viewer)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :developer}
          end.to change { membership.reload.role }.from("viewer").to("developer")

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:notice]).to eq("#{member.email} role was successfully updated to developer")
        end
      end

      context "when user is a viewer" do
        before do
          create(:membership, user: user, organization:, role: :viewer)
          sign_in user.email_authentication
        end

        it "does not allow a viewer to change an owner's role" do
          membership = create(:membership, user: member, organization:, role: :owner)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :developer}
          end.not_to change { membership.reload.role }

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:alert]).to eq("You don't have permission to edit this member's role")
        end

        it "does not allow a viewer to change a developer's role" do
          membership = create(:membership, user: member, organization:, role: :developer)

          expect do
            patch update_user_role_accounts_user_path, params: {email: member.email, role: :owner}
          end.not_to change { membership.reload.role }

          expect(response).to redirect_to(accounts_organization_teams_path(organization))
          expect(flash[:alert]).to eq("You don't have permission to edit this member's role")
        end
      end
    end
  end
end
