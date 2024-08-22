# == Schema Information
#
# Table name: users
#
#  id              :uuid             not null, primary key
#  admin           :boolean          default(FALSE)
#  full_name       :string           not null
#  github_login    :string
#  preferred_name  :string
#  slug            :string           indexed
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  github_id       :string
#  unique_authn_id :string           default(""), not null
#
class Accounts::User < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  self.ignored_columns += %w[confirmation_sent_at confirmation_token confirmed_at current_sign_in_at current_sign_in_ip email encrypted_password failed_attempts last_sign_in_at last_sign_in_ip locked_at remember_created_at reset_password_sent_at reset_password_token sign_in_count unconfirmed_email unlock_token]

  validates :full_name, presence: {message: :not_blank}, length: {maximum: 70, message: :too_long}
  validates :preferred_name, length: {maximum: 70, message: :too_long}
  validates :unique_authn_id, uniqueness: {message: :already_taken, case_sensitive: false}

  has_many :memberships, dependent: :delete_all, inverse_of: :user
  has_many :organizations, -> { where(status: :active).sequential }, through: :memberships
  has_many :all_organizations, through: :memberships, source: :organization
  has_many :sent_invites, class_name: "Invite", foreign_key: "sender_id", inverse_of: :sender, dependent: :destroy
  has_many :invitations, class_name: "Invite", foreign_key: "recipient_id", inverse_of: :recipient, dependent: :destroy
  has_many :commits, foreign_key: "author_login", primary_key: "github_login", dependent: :nullify, inverse_of: :user
  has_many :releases, dependent: :nullify
  has_many :user_authentications, dependent: :destroy, inverse_of: :user
  has_many :sso_authentications,
    dependent: :destroy,
    through: :user_authentications,
    source: :authenticatable,
    source_type: "Accounts::SsoAuthentication"
  has_many :email_authentications,
    dependent: :destroy,
    through: :user_authentications,
    source: :authenticatable,
    source_type: "Accounts::EmailAuthentication"

  friendly_id :full_name, use: :slugged
  auto_strip_attributes :full_name, :preferred_name, squish: true

  accepts_nested_attributes_for :organizations
  accepts_nested_attributes_for :memberships, allow_destroy: false

  def email_authentication
    email_authentications.first
  end

  def sso_authentication
    sso_authentications.first
  end

  def email = unique_authn_id

  class << self
    def find_via_email(email)
      joins(:email_authentications).find_by(email_authentications: {email: email})
    end

    def find_via_sso_email(email)
      joins(:sso_authentications).find_by(sso_authentications: {email: email})
    end

    def valid_signup_domain?(email)
      return false if email.blank?

      parsed_email = Mail::Address.new(email)
      domain = parsed_email.domain
      return false if Accounts::Organization.find_sso_org_by_domain(domain)

      disallowed_domains = ENV["DISALLOWED_SIGN_UP_DOMAINS"]&.split(",")
      return true if disallowed_domains.blank?
      disallowed_domains.exclude?(domain)
    end

    def find_or_create_via_sso(email, organization, full_name:, preferred_name:, login_id:)
      existing_user = find_via_sso_email(email)
      return existing_user if existing_user

      invite = organization.pending_invites.find_by(email:)
      sso_auth = Accounts::SsoAuthentication.new(email:, login_id:)
      sso_auth.add(organization, full_name, preferred_name, invite)
      sso_auth.reload.user if sso_auth.valid?
    end

    def start_sign_in_via_sso(email)
      email = email.downcase
      parsed_email_domain = Mail::Address.new(email).domain
      organization = Accounts::Organization.find_sso_org_by_domain(parsed_email_domain)
      return unless organization

      Accounts::SsoAuthentication.start_sign_in(organization.sso_tenant_id)
    end

    def finish_sign_in_via_sso(code, remote_ip)
      result = Accounts::SsoAuthentication.finish_sign_in(code)
      return unless result.ok?

      auth_data = result.value!
      auth_data => { user_email:, user_full_name:, login_id:, user_preferred_name: }

      parsed_email_domain = Mail::Address.new(user_email).domain
      organization = Accounts::Organization.find_sso_org_by_domain(parsed_email_domain)
      return unless organization

      user = find_or_create_via_sso(user_email, organization, full_name: user_full_name, preferred_name: user_preferred_name, login_id:)
      return unless user
      user.sso_authentication.track_login(remote_ip)

      auth_data
    end

    def onboard_via_email(email_auth)
      if find_via_email(email_auth.email)
        email_auth.errors.add(:account_exists, "you already have an account with tramline!") # FIXME: add error properly
        return email_auth
      end

      unless valid_signup_domain?(email_auth.email)
        email_auth.errors.add(:email, :invalid_domain)
        return email_auth
      end

      new_user = email_auth.user
      new_organization = new_user.organizations.first

      unless new_organization
        email_auth.errors.add(:org_not_found, "invalid request") # FIXME: add error properly
        return email_auth
      end

      new_membership = new_user.memberships.first
      new_organization.status = Accounts::Organization.statuses[:active]
      new_organization.created_by = email_auth.email
      new_membership.role = Accounts::Membership.roles[:owner]
      new_membership.organization = new_organization
      new_user.memberships << new_membership
      new_user.unique_authn_id = email_auth.unique_authn_id
      email_auth.save
      email_auth
    end

    def add_via_email(invite)
      user = invite.recipient
      return unless user&.email_authentication
      user.email_authentication.add(invite)
    end
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

  # FIXME: This assumes that the blob is always a BuildArtifact
  # Eventually, make the URLs domain-specific and not blob-based general ones.
  def access_to_blob?(signed_blob_id)
    build = BuildArtifact.find_by_signed_id(signed_blob_id)
    return false if build.blank?
    access_for(build.organization).present?
  end

  def pending_profile?(organization)
    return false if organization.teams.none?
    github_login.blank? || team_for(organization).blank?
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
