class AddDiscardedAtToTrains < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_column :trains, :discarded_at, :datetime
    add_index :trains, :discarded_at, algorithm: :concurrently
  end
end
