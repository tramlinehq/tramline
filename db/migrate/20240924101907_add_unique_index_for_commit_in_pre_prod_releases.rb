class AddUniqueIndexForCommitInPreProdReleases < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :pre_prod_releases, [:release_platform_run_id, :commit_id, :type], unique: true, algorithm: :concurrently
  end
end
