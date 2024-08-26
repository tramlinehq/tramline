class AddIndexOnTimestampInCommits < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :commits, [:release_id, :timestamp], algorithm: :concurrently
  end
end
