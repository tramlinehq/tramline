require "rails_helper"

describe Accounts::Invite do
  describe "#make" do
    context "when invites are made concurrently" do
      let(:invitee_email) { "foo@example.com" }

      def cleanup
        Accounts::Invite.delete_all
        Accounts::UserAuthentication.delete_all
        Accounts::EmailAuthentication.delete_all
        Accounts::Membership.delete_all
        Accounts::User.delete_all
        Accounts::Organization.delete_all
      end

      it "creates a single invite and sends a single email per organization and invitee", :disable_transactional_tests do
        cleanup

        organization = create(:organization)
        user = create(:user, :as_owner, member_organization: organization)

        # Get IDs for thread usage
        organization_id = organization.id
        user_id = user.id

        expect do
          threads = []
          5.times do
            threads << Thread.new do
              # Each thread gets its own connection and reloads records
              ActiveRecord::Base.connection_pool.with_connection do
                invite = described_class.new(
                  email: invitee_email,
                  organization_id:,
                  role: :viewer
                )
                invite.sender_id = user_id
                invite.make
              end
            end
          end

          threads.each(&:join)
        end.to change { described_class.where(email: invitee_email, organization_id:).count }.by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(1)

        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to include(invitee_email)
      ensure
        cleanup
      end

      it "creates separate invites and sends separate emails for different organization-invitee pair", :disable_transactional_tests do
        cleanup

        organization1 = create(:organization)
        organization2 = create(:organization)
        user1 = create(:user, :as_owner, member_organization: organization1)
        user2 = create(:user, :as_owner, member_organization: organization2)
        invitee_2_email = "bar@example.com"
        invitee_3_email = "baz@example.com"

        expect do
          threads = []
          [
            [invitee_email, organization1.id, user1.id],
            [invitee_2_email, organization1.id, user1.id],
            [invitee_3_email, organization2.id, user2.id]
          ].each do |email, organization_id, sender_id|
            threads << Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                invite = described_class.new(
                  email:,
                  organization_id:,
                  role: :viewer
                )
                invite.sender_id = sender_id
                invite.make
              end
            end
          end

          threads.each(&:join)
        end.to change { described_class.where(email: invitee_email, organization_id: organization1.id).count }.by(1)
          .and change { described_class.where(email: invitee_2_email, organization_id: organization1.id).count }.by(1)
          .and change { described_class.where(email: invitee_3_email, organization_id: organization2.id).count }.by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(3)
      ensure
        cleanup
      end
    end

    it "reports only the validation error when the invitee already has a pending invite" do
      existing = create(:invite)
      invite = described_class.new(email: existing.email, organization: existing.organization, sender: existing.sender, role: "viewer")

      expect(invite.make).to be(false)
      expect(invite.errors[:recipient]).to include("has already been invited to the organization!")
      expect(invite.errors[:email]).to be_empty
    end

    it "does not keep the invite when the email cannot be delivered" do
      organization = create(:organization)
      sender = create(:user, :as_owner, member_organization: organization)
      allow(InvitationMailer).to receive(:new_user).and_raise(StandardError, "delivery failed")
      invite = described_class.new(email: "new-invitee@example.com", organization:, sender:, role: "viewer")

      expect { expect(invite.make).to be(false) }.not_to change(described_class, :count)
      expect(invite.errors[:email]).to include("Failed to deliver an invite email to new-invitee@example.com! Please try again or contact support if the issue persists.")
    end
  end
end
