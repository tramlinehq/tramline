require "rails_helper"

describe Accounts::Membership do
  let!(:organization) { create(:organization) }

  let(:owner_email) { Faker::Internet.email }
  let(:owner) { create(:user, unique_authn_id: owner_email) }
  let(:developer_email) { Faker::Internet.email }
  let(:developer) { create(:user, :as_developer, unique_authn_id: developer_email) }
  let(:viewer_email) { Faker::Internet.email }
  let(:viewer) { create(:user, unique_authn_id: viewer_email) }

  let(:owner_membership) { create(:membership, user: owner, organization: organization, role: "owner") }
  let(:developer_membership) { create(:membership, user: developer, organization: organization, role: "developer") }
  let(:viewer_membership) { create(:membership, user: viewer, organization: organization, role: "viewer") }

  before do
    create(:email_authentication, email: owner_email, user: owner)
    create(:email_authentication, email: developer_email, user: developer)
    create(:email_authentication, email: viewer_email, user: viewer)
  end

  describe "#valid_role_change" do
    context "when changing the role of an owner" do
      it "prevents downgrading an owner to developer" do
        owner_membership.role = "developer"
        owner_membership.save

        expect(owner_membership.errors[:role]).to include("Owners cannot be downgraded.")
      end
    end

    context "when changing the role of a viewer" do
      it "prevents viewer from upgrading directly to owner" do
        viewer_membership.role = "owner"
        viewer_membership.save

        expect(viewer_membership.errors[:role]).to include("Viewers can only upgrade to developer not owner.")
      end

      it "allows viewer to upgrade to developer" do
        viewer_membership.role = "developer"
        expect(viewer_membership.save).to be_truthy
        expect(viewer_membership.errors[:role]).to be_empty
      end
    end

    context "when changing the role of a developer" do
      it "allows developer to be upgraded to owner" do
        developer_membership.role = "owner"
        expect(developer_membership.save).to be_truthy
        expect(developer_membership.errors[:role]).to be_empty
      end

      it "does not throw an error when no role change occurs" do
        developer_membership.role = "developer"
        expect(developer_membership.save).to be_truthy
        expect(developer_membership.errors[:role]).to be_empty
      end
    end
  end
end
