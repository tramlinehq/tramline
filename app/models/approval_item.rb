# == Schema Information
#
# Table name: approval_items
#
#  id             :bigint           not null, primary key
#  approved_at    :datetime         indexed
#  content        :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  approved_by_id :uuid             indexed
#  author_id      :uuid             not null, indexed
#  release_id     :uuid             not null, indexed
#
class ApprovalItem < ApplicationRecord
  MAX_CONTENT_LENGTH = 200

  belongs_to :release
  belongs_to :author, class_name: "Accounts::User"
  belongs_to :approved_by, class_name: "Accounts::User", optional: true
  has_many :approval_assignees, dependent: :destroy

  validates :content, presence: true, length: {maximum: ApprovalItem::MAX_CONTENT_LENGTH}
end
