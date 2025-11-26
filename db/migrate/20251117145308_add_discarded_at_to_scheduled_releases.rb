class AddDiscardedAtToScheduledReleases < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_column :scheduled_releases, :discarded_at, :datetime
    add_index :scheduled_releases, :discarded_at, algorithm: :concurrently
  end
end
