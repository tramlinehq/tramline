# frozen_string_literal: true

class BackfillUserUniqueAuthnId < ActiveRecord::Migration[7.0]
  def up
    return

    Accounts::User.all.each do |user|
      next if user.unique_authn_id.present?
      user.update!(unique_authn_id: user.email_authentication.unique_authn_id)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
