# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  admin                  :boolean          default(FALSE)
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default("")
#  encrypted_password     :string           default("")
#  failed_attempts        :integer          default(0), not null
#  full_name              :string           not null
#  github_login           :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  preferred_name         :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  slug                   :string           indexed
#  unconfirmed_email      :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  github_id              :string
#
class Accounts::User < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  AUTHENTICATION_TYPES = {
    sso_authentication: "SsoAuthentication",
    email_authentication: "EmailAuthentication"
  }.freeze

  # devise :database_authenticatable, :registerable, :trackable, :lockable,
  #   :recoverable, :confirmable, :timeoutable, :rememberable
  # validates :password, password_strength: true, allow_nil: true
  # # this is in addition to devise's validatable
  # validates :email, presence: {message: :not_blank},
  #   uniqueness: {case_sensitive: false, message: :already_taken},
  #   length: {maximum: 105, message: :too_long}

  validates :full_name, presence: {message: :not_blank}, length: {maximum: 70, message: :too_long}
  validates :preferred_name, length: {maximum: 70, message: :too_long}

  has_many :memberships, dependent: :delete_all, inverse_of: :user
  has_many :organizations, -> { where(status: :active).sequential }, through: :memberships
  has_many :all_organizations, through: :memberships, source: :organization
  has_many :sent_invites, class_name: "Invite", foreign_key: "sender_id", inverse_of: :sender, dependent: :destroy
  has_many :invitations, class_name: "Invite", foreign_key: "recipient_id", inverse_of: :recipient, dependent: :destroy
  has_many :commits, foreign_key: "author_login", primary_key: "github_login", dependent: :nullify, inverse_of: :user
  has_many :releases, dependent: :nullify
  has_one :user_authentication, dependent: :destroy, inverse_of: :user
  has_one :sso_authentication,
    dependent: :destroy,
    through: :user_authentication,
    source: :authenticatable,
    source_type: "Accounts::SsoAuthentication"
  has_one :email_authentication,
    dependent: :destroy,
    through: :user_authentication,
    source: :authenticatable,
    source_type: "Accounts::EmailAuthentication"

  friendly_id :full_name, use: :slugged
  auto_strip_attributes :full_name, :preferred_name, squish: true

  accepts_nested_attributes_for :organizations
  accepts_nested_attributes_for :memberships, allow_destroy: false

  delegate :email, to: :email_authentication, allow_nil: true

  def self.find_via_email(email)
    joins(:email_authentication).find_by(email_authentication: {email: email})
  end

  def self.valid_email_domain?(email)
    return false if email.blank?

    begin
      disallowed_domains = ENV["DISALLOWED_SIGN_UP_DOMAINS"].split(",")
      parsed_email = Mail::Address.new(email)
      disallowed_domains.include?(parsed_email.domain)
    rescue
      false
    end
  end

  def self.onboard_via_email(email_auth)
    if find_via_email(email_auth.email)
      email_auth.errors.add(:account_exists, "you already have an account with tramline!")
      return email_auth
    end

    if valid_email_domain?(email_auth.email)
      email_auth.errors.add(:email, :invalid_domain)
      return email_auth
    end

    new_user = email_auth.user
    new_organization = new_user.organizations.first

    unless new_organization
      email_auth.errors.add(:org_not_found, "invalid request")
      return email_auth
    end

    new_membership = new_user.memberships.first
    new_organization.status = Accounts::Organization.statuses[:active]
    new_organization.created_by = email_auth.email
    new_membership.role = Accounts::Membership.roles[:owner]
    new_membership.organization = new_organization
    new_user.memberships << new_membership
    email_auth.save
    email_auth
  end

  def role_for(organization)
    access_for(organization).role
  end

  def team_for(organization)
    access_for(organization)&.team
  end

  def writer_for?(organization)
    access_for(organization).writer?
  end

  def owner_for?(organization)
    access_for(organization).owner?
  end

  def successful_invite_for(organization)
    invitations
      .filter { |i| i.organization == organization }
      .find(&:accepted?)
  end

  def release_monitoring?
    Flipper.enabled?(:release_monitoring, self)
  end

  def reldex_enabled?
    Flipper.enabled?(:reldex_enabled, self)
  end

  # FIXME: This assumes that the blob is always a BuildArtifact
  # Eventually, make the URLs domain-specific and not blob-based general ones.
  def access_to_blob?(signed_blob_id)
    build = BuildArtifact.find_by_signed_id(signed_blob_id)
    return false if build.blank?
    access_for(build.organization).present?
  end

  protected

  def confirmation_required?
    true
  end

  private

  def access_for(organization)
    memberships.find_by(organization: organization)
  end
end
