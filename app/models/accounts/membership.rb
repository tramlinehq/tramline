# == Schema Information
#
# Table name: memberships
#
#  id              :uuid             not null, primary key
#  user_id         :uuid
#  organization_id :uuid
#  role            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Accounts::Membership < ApplicationRecord
  include Roleable
  has_paper_trail

  belongs_to :user, inverse_of: :memberships, optional: false
  belongs_to :organization, inverse_of: :memberships, optional: false

  validates :user_id, uniqueness: { scope: :organization_id }

  after_initialize :set_default_role, if: :new_record?

  def self.allowed_roles
    roles.except(:owner).transform_keys(&:titleize).to_a
  end

  def set_default_role
    self.role = "developer"
  end

  def writer?
    role.in? %w[owner developer]
  end
end
