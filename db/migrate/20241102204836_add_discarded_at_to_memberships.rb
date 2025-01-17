class AddDiscardedAtToMemberships < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :memberships, :discarded_at, :datetime
    add_index :memberships, :discarded_at, algorithm: :concurrently
  end
end
