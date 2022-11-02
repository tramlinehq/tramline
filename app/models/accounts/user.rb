# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  full_name              :string           not null
#  preferred_name         :string
#  slug                   :string
#  admin                  :boolean          default(FALSE)
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string
#  last_sign_in_ip        :string
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#  failed_attempts        :integer          default(0), not null
#  unlock_token           :string
#  locked_at              :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class Accounts::User < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  devise :database_authenticatable, :registerable, :trackable, :lockable,
    :recoverable, :confirmable, :timeoutable, :rememberable, :validatable

  validates :password, password_strength: {use_dictionary: true}, allow_nil: true
  validates :email, presence: true,
    uniqueness: {case_sensitive: false},
    length: {maximum: 105},
    format: {with: URI::MailTo::EMAIL_REGEXP}

  after_validation :strip_unnecessary_errors

  has_many :memberships, dependent: :delete_all, inverse_of: :user
  has_many :organizations, -> { where(status: :active) }, through: :memberships
  # NOTE: For now assume that user has only one organisation
  has_one :membership, dependent: :delete, inverse_of: :user
  has_one :organization, -> { where(status: :active) }, through: :membership
  has_many :all_organizations, through: :memberships, source: :organization
  has_many :sent_invites, class_name: "Invite", foreign_key: "sender_id", inverse_of: :sender, dependent: :destroy
  has_many :invitations, class_name: "Invite", foreign_key: "recipient_id", inverse_of: :recipient, dependent: :destroy

  friendly_id :full_name, use: :slugged

  auto_strip_attributes :full_name, :preferred_name, squish: true

  accepts_nested_attributes_for :organizations

  delegate :role, to: :membership

  def onboard!
    return false unless valid?
    return false if membership.blank?
    return false if organization.blank?

    membership&.role = Accounts::Membership.roles[:owner]
    organization.created_by = email
    organization.status = Accounts::Organization.statuses[:active]
    save!

    self
  end

  def add!(invite)
    return false unless valid?

    transaction do
      invite.mark_accepted!
      memberships.new(organization: invite.organization, role: invite.role)
      save!
    end
  end

  private

  # We only want to display one error message to the user, so if we get multiple
  # exceptions clear out all exceptions and present our nice message to the user.
  def strip_unnecessary_errors
    if errors[:password].any? && errors[:password].size > 1
      errors.delete(:password)
      errors.add(:password, I18n.t("errors.messages.password.password_strength"))
    end
  end
end
