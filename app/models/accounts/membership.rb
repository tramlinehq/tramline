class Accounts::Membership < ApplicationRecord
  include Roleable
  has_paper_trail

  belongs_to :user, inverse_of: :memberships, required: true
  belongs_to :organization, inverse_of: :memberships, required: true

  validates :user_id, uniqueness: { scope: :organization_id }

  after_initialize :set_default_role, if: :new_record?


  def set_default_role
    self.role = 'developer'
  end
end
