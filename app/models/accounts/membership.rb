# == Schema Information
#
# Table name: memberships
#
#  id              :uuid             not null, primary key
#  role            :string           not null, indexed, indexed => [user_id, organization_id]
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             indexed, indexed => [user_id, role]
#  team_id         :uuid
#  user_id         :uuid             indexed => [organization_id, role]
#
class Accounts::Membership < ApplicationRecord
  include Roleable
  has_paper_trail

  belongs_to :user, inverse_of: :memberships, optional: false
  belongs_to :organization, inverse_of: :memberships, optional: false
  belongs_to :team, inverse_of: :memberships, optional: true

  validates :user_id, uniqueness: {scope: :organization_id}
  validate :team_can_only_be_set_once
  validate :valid_role_change, on: :update

  def self.allowed_roles
    roles.except(:owner).transform_keys(&:titleize).to_a
  end

  def self.all_roles
    roles.transform_keys(&:titleize).to_a
  end

  def writer?
    role.in? %w[owner developer]
  end

  def team_set?
    team.present?
  end

  def team_can_only_be_set_once
    if team_id_changed? && team_id_was.present?
      errors.add(:team_id, "cannot be changed once set")
      false
    end
  end

  private

  def valid_role_change
    user_membership = user.memberships.find_by(organization: organization)
    return if user_membership.nil? || role == role_was

    if role_was == "owner"
      validate_owner_role_change
    elsif role_was == "viewer"
      validate_viewer_role_change
    end
  end

  def validate_owner_role_change
    errors.add(:role, "Owners cannot be downgraded.")
  end

  def validate_viewer_role_change
    if role == "owner"
      errors.add(:role, "Viewers can only upgrade to developer not owner.")
    end
  end
end
