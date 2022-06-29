class Accounts::Invite < ActiveRecord::Base
  include Roleable
  include Rails.application.routes.url_helpers

  belongs_to :organization
  belongs_to :sender, class_name: "Accounts::User"
  belongs_to :recipient, class_name: "Accounts::User", optional: true

  validate :user_already_in_organization, on: :create
  validate :user_already_invited, on: :create
  validate :accept_only_once, on: :mark_accepted!

  before_save :add_recipient
  before_create :generate_token

  def generate_token
    self.token = Digest::SHA1.hexdigest([organization_id, Time.now, rand].join)
  end

  def add_recipient
    recipient = Accounts::User.find_by_email(email)

    if recipient
      self.recipient = recipient
    end
  end

  def user_already_in_organization
    recipient = Accounts::User.find_by_email(email)

    if organization.users.find_by_id(recipient)
      errors.add(:recipient, "already exists in the organization!")
    end
  end

  def user_already_invited
    if Accounts::Invite.where(email: email, accepted_at: nil, organization: organization).exists?
      errors.add(:recipient, "has already been invited to the organization!")
    end
  end

  def mark_accepted!
    update!(accepted_at: Time.now)
  end

  def accept_only_once
    if accepted_at.present?
      errors.add(:recipient, "has already accepted the invite!")
    end
  end

  def registration_url
    params = {
      host: ENV["HOST_NAME"],
      protocol: "https",
      invite_token: token
    }

    if Rails.env.development?
      new_user_registration_url(params.merge(port: ENV["PORT_NUM"]))
    else
      new_user_registration_url(params)
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
