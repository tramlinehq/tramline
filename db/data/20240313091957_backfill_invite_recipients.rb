# frozen_string_literal: true

class BackfillInviteRecipients < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      Accounts::Invite.where(recipient_id: nil).each do |invite|
        recipient = Accounts::User.find_by(email: invite.email)
        next unless recipient
        invite.recipient = recipient
        invite.save!(validate: false)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
