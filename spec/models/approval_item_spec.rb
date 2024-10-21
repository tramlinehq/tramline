require "rails_helper"

describe ApprovalItem do
  it "has a valid factory" do
    expect(create(:approval_item)).to be_valid
  end

  it "only allows release pilots to be authors" do
    pilot = create(:user, :with_email_authentication, :as_developer)
    release = create(:release, release_pilot: pilot)
    approval_item = create(:approval_item, release:, author: pilot)
    expect(approval_item).to be_valid

    pilot = create(:user, :as_developer, member_organization: release.organization)
    release = create(:release)
    approval_item = build(:approval_item, release:, author: pilot)
    expect(approval_item).not_to be_valid
  end

  describe "#approve" do
    let(:pilot) { create(:user, :with_email_authentication, :as_developer) }
    let(:release) { create(:release, release_pilot: pilot) }
    let(:approval_item) { create(:approval_item, release:, author: pilot) }

    it "can be approved by the assigned users" do
      assignee_1 = create(:user, :as_developer, member_organization: approval_item.organization)
      create(:approval_assignee, approval_item:, assignee: assignee_1)
      assignee_2 = create(:user, :as_developer, member_organization: approval_item.organization)
      create(:approval_assignee, approval_item:, assignee: assignee_2)

      expect(approval_item.approve(assignee_1)).to be(true)
      expect(approval_item.approve(assignee_2)).to be(true)
      expect(approval_item.errors).not_to be_present
    end

    it "cannot be approved by unassigned users" do
      unassigned = create(:user, :as_developer, member_organization: approval_item.organization)

      expect(approval_item.approve(unassigned)).to be(false)
      expect(approval_item.errors).to be_present
    end

    it "allows pilots to self approve if there are no assignees" do
      expect(approval_item.approval_assignees).to be_empty
      expect(approval_item.approve(approval_item.author)).to be(true)
      expect(approval_item.errors).not_to be_present
    end
  end

  describe ".approved" do
    let(:pilot) { create(:user, :with_email_authentication, :as_developer) }
    let(:release) { create(:release, release_pilot: pilot) }

    it "returns only approved items" do
      _item_1 = create(:approval_item, release:, author: pilot)
      _item_2 = create(:approval_item, release:, author: pilot, approved_at: Time.current)
      approved_item = create(:approval_item, release:, author: pilot, approved_by: pilot, approved_at: Time.current)

      expect(release.approval_items.approved).to contain_exactly(approved_item)
    end
  end
end
