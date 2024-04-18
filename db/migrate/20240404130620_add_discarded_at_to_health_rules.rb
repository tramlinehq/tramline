class AddDiscardedAtToHealthRules < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    add_column :release_health_rules, :discarded_at, :datetime
    add_index :release_health_rules, :discarded_at, algorithm: :concurrently
  end
end
