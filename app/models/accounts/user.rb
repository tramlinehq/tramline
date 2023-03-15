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
  include Flipper::Identifier
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
  has_many :all_organizations, through: :memberships, source: :organization
  has_many :sent_invites, class_name: "Invite", foreign_key: "sender_id", inverse_of: :sender, dependent: :destroy
  has_many :invitations, class_name: "Invite", foreign_key: "recipient_id", inverse_of: :recipient, dependent: :destroy

  friendly_id :full_name, use: :slugged

  auto_strip_attributes :full_name, :preferred_name, squish: true

  accepts_nested_attributes_for :organizations

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

  def role_for(organization)
    memberships.find_by(organization: organization).role
  end

  def writer_for?(organization)
    memberships.find_by(organization: organization).writer?
  end

  protected

  # keeping the devise confirmable module around and disabling like this,
  # in case we need to bring it back in some way
  def confirmation_required?
    false
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
