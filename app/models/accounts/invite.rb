class Accounts::Invite < ActiveRecord::Base
  include Roleable
  include Rails.application.routes.url_helpers

  belongs_to :organization
  belongs_to :sender, class_name: "Accounts::User"
  belongs_to :recipient, class_name: "Accounts::User", optional: true

  validate :user_already_in_organization, on: :create
  before_save :add_recipient
  before_create :generate_token

  def generate_token
    self.token = Digest::SHA1.hexdigest([self.organization_id, Time.now, rand].join)
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

  def registration_url
    if Rails.env.development?
      new_user_registration_url(host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"], invite_token: token)
    else
      new_user_registration_url(host: ENV["HOST_NAME"], protocol: "https", invite_token: token)
    end
  end

  def mark_accepted!
    update!(accepted_at: Time.now)
  end
end
