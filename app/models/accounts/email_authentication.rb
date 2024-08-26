# == Schema Information
#
# Table name: email_authentications
#
#  id                     :uuid             not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string           indexed
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null, indexed
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string           indexed
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  unlock_token           :string           indexed
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class Accounts::EmailAuthentication < ApplicationRecord
  has_one :user_authentication, as: :authenticatable, dependent: :destroy
  has_one :user, through: :user_authentication

  devise :database_authenticatable, :registerable, :trackable, :lockable,
    :recoverable, :confirmable, :timeoutable, :rememberable, :validatable

  validates :password, password_strength: true, allow_nil: true
  validates :email, presence: {message: :not_blank},
    uniqueness: {case_sensitive: false, message: :already_taken},
    length: {maximum: 105, message: :too_long} # this is in addition to devise's validatable

  delegate :full_name, :preferred_name, :admin?, to: :user, allow_nil: true
  delegate :organizations, :memberships, to: :user

  accepts_nested_attributes_for :user

  def sign_up_email=(email)
    self.email = email
  end

  def sign_up_email
    email
  end

  # TODO: [nplus1]
  def active_for_authentication?
    super && email_auth_allowed?
  end

  def inactive_message
    email_auth_allowed? ? super : :only_sso_allowed
  end

  def email_auth_allowed?
    return true if user.admin?

    parsed_email_domain = Mail::Address.new(email).domain
    sso_org = Accounts::Organization.find_sso_org_by_domain(parsed_email_domain)
    return true if sso_org.blank?
    sso_org.allow_email_auth_for_sso?
  end

  def organization
    user.organizations.first
  end

  def unique_authn_id
    email
  end

  def add(invite)
    user.unique_authn_id = unique_authn_id
    user.memberships.new(organization: invite.organization, role: invite.role)
    invite.mark_accepted(user) if save
  end
end
