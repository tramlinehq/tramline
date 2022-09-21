class Accounts::User < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  devise :database_authenticatable, :registerable, :trackable, :lockable,
    :recoverable, :confirmable, :timeoutable, :rememberable, :validatable

  validates :password, password_strength: {use_dictionary: true}, allow_nil: true
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
