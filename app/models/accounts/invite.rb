class Accounts::Invite < ApplicationRecord
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
    self.token = Digest::SHA1.hexdigest([organization_id, Time.zone.now, rand].join)
  end

  def add_recipient
    recipient = Accounts::User.find_by(email: email)

    self.recipient = recipient if recipient
  end

  def user_already_in_organization
    recipient = Accounts::User.find_by(email: email)

    errors.add(:recipient, "already exists in the organization!") if organization.users.find_by(id: recipient)
  end

  def user_already_invited
    errors.add(:recipient, "has already been invited to the organization!") if Accounts::Invite.exists?(email: email, accepted_at: nil, organization: organization)
  end

  def mark_accepted!
    update!(accepted_at: Time.zone.now)
  end

  def accept_only_once
    errors.add(:recipient, "has already accepted the invite!") if accepted_at.present?
  end

  def registration_url
    params = {
      host: ENV.fetch("HOST_NAME", nil),
      protocol: "https",
      invite_token: token
    }

    if Rails.env.development?
      new_user_registration_url(params.merge(port: ENV.fetch("PORT_NUM", nil)))
    else
      new_user_registration_url(params)
    end
  end

  def accept_url
    params = {
      host: ENV.fetch("HOST_NAME", nil),
      protocol: "https",
      invite_token: token
    }

    if Rails.env.development?
      new_authentication_invite_confirmation_url(params.merge(port: ENV.fetch("PORT_NUM", nil)))
    else
      new_authentication_invite_confirmation_url(params)
    end
  end
end
