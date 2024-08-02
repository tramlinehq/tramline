# == Schema Information
#
# Table name: invites
#
#  id              :uuid             not null, primary key
#  accepted_at     :datetime
#  email           :string
#  role            :string
#  token           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null, indexed
#  recipient_id    :uuid             indexed
#  sender_id       :uuid             not null, indexed
#
class Accounts::Invite < ApplicationRecord
  include Loggable
  include Roleable
  include Rails.application.routes.url_helpers

  belongs_to :organization
  belongs_to :sender, class_name: "Accounts::User"
  belongs_to :recipient, class_name: "Accounts::User", optional: true

  validate :user_already_in_organization, on: :create
  validate :user_already_invited, on: :create
  validate :accept_only_once, on: :mark_accepted!
  validate :allow_only_approved_domains_for_sso, on: :create, if: -> { organization.sso? }
  validates :role, inclusion: {in: roles.slice("developer", "viewer").keys, message: :cannot_invite_owner}
  validates :email, presence: {message: :not_blank},
    length: {maximum: 105, message: :too_long},
    format: {
      with: URI::MailTo::EMAIL_REGEXP,
      message: :invalid_format
    }

  before_save -> { self.email = email.downcase }
  before_save :add_recipient
  before_create :generate_token

  scope :not_accepted, -> { where(accepted_at: nil) }

  def generate_token
    self.token = Digest::SHA1.hexdigest([organization_id, Time.zone.now, rand].join)
  end

  def make
    result = GitHub::Result.new do
      transaction do
        return unless save

        if organization.sso?
          InvitationMailer.sso_user(self).deliver
        elsif recipient.present?
          InvitationMailer.existing_user(self).deliver
        else
          InvitationMailer.new_user(self).deliver
        end
      end
    end

    unless result.ok?
      elog(result.error)
      errors.add(:email, :delivery_failed, email: email)
      return false
    end

    true
  end

  def add_recipient
    recipient = Accounts::User.find_via_email(email)

    if recipient
      self.recipient = recipient
    end
  end

  def user_already_in_organization
    recipient = Accounts::User.find_via_email(email)

    if organization.users.find_by(id: recipient)
      errors.add(:recipient, "already exists in the organization!")
    end
  end

  def user_already_invited
    if Accounts::Invite.exists?(email: email, accepted_at: nil, organization: organization)
      errors.add(:recipient, "has already been invited to the organization!")
    end
  end

  def mark_accepted(recipient)
    update(accepted_at: Time.zone.now, recipient: recipient)
  end

  def accept_only_once
    if accepted?
      errors.add(:recipient, "has already accepted the invite!")
    end
  end

  def allow_only_approved_domains_for_sso
    unless organization.valid_sso_domain?(email)
      errors.add(:email, "domain is not allowed for Single Sign-On!")
    end
  end

  def accepted?
    accepted_at.present?
  end

  def sso_login_url
    params = {
      host: ENV["HOST_NAME"],
      protocol: "https",
      invite_token: token
    }

    if Rails.env.development?
      sso_new_sso_session_url(params.merge(port: ENV["PORT_NUM"]))
    else
      sso_new_sso_session_url(params)
    end
  end

  def registration_url
    params = {
      host: ENV["HOST_NAME"],
      protocol: "https",
      invite_token: token
    }

    if Rails.env.development?
      new_email_authentication_registration_url(params.merge(port: ENV["PORT_NUM"]))
    else
      new_email_authentication_registration_url(params)
    end
  end

  def accept_url
    params = {
      host: ENV["HOST_NAME"],
      protocol: "https",
      invite_token: token
    }

    if Rails.env.development?
      new_authentication_invite_confirmation_url(params.merge(port: ENV["PORT_NUM"]))
    else
      new_authentication_invite_confirmation_url(params)
    end
  end
end
