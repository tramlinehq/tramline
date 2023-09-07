class AddHeadRefIndexOnPullRequests < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :pull_requests, [:release_id, :head_ref], algorithm: :concurrently
  end
end
