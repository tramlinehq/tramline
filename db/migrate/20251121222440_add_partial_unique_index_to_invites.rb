class AddPartialUniqueIndexToInvites < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :invites, [:email, :organization_id],
              where: "accepted_at IS NULL",
              unique: true,
              name: "index_invites_unique_pending",
              algorithm: :concurrently
  end
end
