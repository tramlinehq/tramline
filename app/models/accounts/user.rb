# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  admin                  :boolean          default(FALSE)
#  confirmation_sent_at   :datetime
#  confirmation_token     :string           indexed
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null, indexed
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  full_name              :string           not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  preferred_name         :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string           indexed
#  sign_in_count          :integer          default(0), not null
#  slug                   :string           indexed
#  unconfirmed_email      :string
#  unlock_token           :string           indexed
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class Accounts::User < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  devise :database_authenticatable, :registerable, :trackable, :lockable,
    :recoverable, :confirmable, :timeoutable, :rememberable, :validatable

  # this is in addition to devise's validatable
  validates :password, password_strength: true, allow_nil: true

  validates :email, presence: true,
    uniqueness: {case_sensitive: false},
    length: {maximum: 105},
    format: {with: URI::MailTo::EMAIL_REGEXP}

  has_many :memberships, dependent: :delete_all, inverse_of: :user
  has_many :organizations, -> { where(status: :active) }, through: :memberships
  has_many :all_organizations, through: :memberships, source: :organization
  has_many :sent_invites, class_name: "Invite", foreign_key: "sender_id", inverse_of: :sender, dependent: :destroy
  has_many :invitations, class_name: "Invite", foreign_key: "recipient_id", inverse_of: :recipient, dependent: :destroy

  friendly_id :full_name, use: :slugged

  auto_strip_attributes :full_name, :preferred_name, squish: true

  accepts_nested_attributes_for :organizations

  def self.onboard(user)
    if find_by(email: user.email)
      user.errors.add(:account_exists, "you already have an account with tramline!")
      return user
    end

    new_organization = user.organizations.first
    new_membership = user.memberships.first
    new_organization.status = Accounts::Organization.statuses[:active]
    new_organization.created_by = user.email
    new_membership.role = Accounts::Membership.roles[:owner]
    new_membership.organization = new_organization
    user.memberships << new_membership
    user.save
    user
  end

  def add!(invite)
    return false unless valid?

    transaction do
      invite.mark_accepted!
      memberships.new(organization: invite.organization, role: invite.role)
      save!
    end
  end

  def role_for(organization)
    memberships.find_by(organization: organization).role
  end

  def writer_for?(organization)
    memberships.find_by(organization: organization).writer?
  end

  def owner_for?(organization)
    memberships.find_by(organization: organization).owner?
  end

  protected

  def confirmation_required?
    true
  end
end
