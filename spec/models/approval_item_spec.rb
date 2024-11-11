require "rails_helper"

describe ApprovalItem do
  let(:organization) { create(:organization, :with_owner_membership) }
  let(:app) { create(:app, :android, organization:) }
  let(:approvals_enabled_train) { create(:train, approvals_enabled: true, app:) }
  let(:approvals_disabled_train) { create(:train, approvals_enabled: false, app:) }

  it "has a valid factory" do
    expect(create(:approval_item)).to be_valid
  end

  it "only allows writers to be authors" do
    pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
    release = create(:release, release_pilot: pilot, train: approvals_enabled_train)
    approval_item = create(:approval_item, release:, author: pilot)
    expect(approval_item).to be_valid

    pilot = create(:user, :as_viewer, member_organization: release.organization)
    release = create(:release, train: approvals_enabled_train)
    approval_item = build(:approval_item, release:, author: pilot)
    expect(approval_item).not_to be_valid
  end

  it "only allows creating items when enabled on a train level" do
    pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
    release = create(:release, train: approvals_disabled_train, release_pilot: pilot)
    approval_item = build(:approval_item, release:, author: pilot)
    expect(approval_item).not_to be_valid

    pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
    release = create(:release, train: approvals_enabled_train, release_pilot: pilot)
    approval_item = create(:approval_item, release:, author: pilot)
    expect(approval_item).to be_valid
  end

  it "does not allow deleting items when they are not not_started" do
    pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
    release = create(:release, release_pilot: pilot, train: approvals_enabled_train)
    approval_item = create(:approval_item, :approved, release:, author: pilot)

    expect(approval_item.destroy).to be(false)
    expect(approval_item.errors[:base]).to include("Cannot delete an approval item that has already started.")
  end

  it "does not allow invalid statuses" do
    pilot = create(:user, :with_email_authentication, :as_developer, member_organization: organization)
    release = create(:release, release_pilot: pilot, train: approvals_enabled_train)
    approval_item_1 = build(:approval_item, status: nil, release:, author: pilot)
    approval_item_2 = build(:approval_item, status: "killed", release:, author: pilot)

    expect(approval_item_1).not_to be_valid
    expect(approval_item_2).not_to be_valid
  end

  describe "#update_status" do
    let(:pilot) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
    let(:release) { create(:release, release_pilot: pilot, train: approvals_enabled_train) }
    let(:approval_item) { create(:approval_item, release:, author: pilot) }

    it "can be updated by the assigned users" do
      assignee_1 = create(:user, :as_developer, member_organization: approval_item.organization)
      create(:approval_assignee, approval_item:, assignee: assignee_1)
      assignee_2 = create(:user, :as_developer, member_organization: approval_item.organization)
      create(:approval_assignee, approval_item:, assignee: assignee_2)

      expect(approval_item.update_status("in_progress", assignee_1)).to be(true)
      expect(approval_item.update_status("approved", assignee_2)).to be(true)
      expect(approval_item.errors).not_to be_present
    end

    it "cannot be updated by unassigned users" do
      unassigned = create(:user, :as_developer, member_organization: approval_item.organization)

      expect(approval_item.update_status("in_progress", unassigned)).to be(false)
      expect(approval_item.errors).to be_present
    end

    it "allows pilots to self updated if there are no assignees" do
      expect(approval_item.approval_assignees).to be_empty
      expect(approval_item.update_status("blocked", approval_item.author)).to be(true)
      expect(approval_item.errors).not_to be_present
    end

    it "updates the status_changed_at and status_changed_by fields" do
      expect(approval_item.update_status("approved", approval_item.author)).to be(true)
      expect(approval_item.status_changed_at).to be_present
      expect(approval_item.status_changed_by).to eq(approval_item.author)
    end
  end

  describe ".approved" do
    let(:pilot) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
    let(:release) { create(:release, release_pilot: pilot, train: approvals_enabled_train) }

    it "returns only approved items" do
      _item_1 = create(:approval_item, release:, author: pilot)
      _item_2 = create(:approval_item, release:, author: pilot, status_changed_at: Time.current)
      approved_item = create(:approval_item, release:, author: pilot, status: "approved", status_changed_by: pilot, status_changed_at: Time.current)

      expect(release.approval_items.reload.approved).to contain_exactly(approved_item)
    end
  end
end
