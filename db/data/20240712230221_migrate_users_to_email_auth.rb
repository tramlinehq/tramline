# frozen_string_literal: true

class MigrateUsersToEmailAuth < ActiveRecord::Migration[7.0]
  def up
    Accounts::User.all.each do |user|
      next if user.email_authentication.present?
      user_attrs = user.attributes

      params = {
        email: user_attrs["email"],
        reset_password_token: user_attrs["reset_password_token"],
        reset_password_sent_at: user_attrs["reset_password_sent_at"],
        remember_created_at: user_attrs["remember_created_at"],
        sign_in_count: user_attrs["sign_in_count"],
        current_sign_in_at: user_attrs["current_sign_in_at"],
        current_sign_in_ip: user_attrs["current_sign_in_ip"],
        last_sign_in_at: user_attrs["last_sign_in_at"],
        last_sign_in_ip: user_attrs["last_sign_in_ip"],
        confirmation_token: user_attrs["confirmation_token"],
        confirmed_at: user_attrs["confirmed_at"],
        confirmation_sent_at: user_attrs["confirmation_sent_at"],
        unconfirmed_email: user_attrs["unconfirmed_email"],
        failed_attempts: user_attrs["failed_attempts"],
        unlock_token: user_attrs["unlock_token"],
        locked_at: user_attrs["locked_at"],
        updated_at: user_attrs["updated_at"],
        created_at: user_attrs["created_at"]
      }

      email_auth = user.build_email_authentication(params)
      email_auth.update_attribute(:encrypted_password, user_attrs["encrypted_password"])
      user.email_authentication = email_auth
      user.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
