require "rails_helper"

describe ApprovalAssignee do
  it "has a valid factory" do
    expect(create(:approval_assignee)).to be_valid
  end

  it "must have the assignee be a part of the org" do
    user = create(:user, :as_developer)
    approval_item = create(:approval_item)
    approval_assignee = build(:approval_assignee, approval_item:, assignee: user)
    expect(approval_assignee).not_to be_valid

    approval_item = create(:approval_item)
    user = create(:user, :as_developer, member_organization: approval_item.organization)
    approval_assignee = build(:approval_assignee, approval_item:, assignee: user)
    expect(approval_assignee).to be_valid
  end
end
