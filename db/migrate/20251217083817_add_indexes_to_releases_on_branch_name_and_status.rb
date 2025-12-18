class AddIndexesToReleasesOnBranchNameAndStatus < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :releases, :branch_name, algorithm: :concurrently
    add_index :releases, :status, algorithm: :concurrently
  end
end
