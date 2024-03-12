class AddDiscardedAtToSteps < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :steps, :discarded_at, :datetime
    add_index :steps, :discarded_at, algorithm: :concurrently
  end
end
