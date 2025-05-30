class AddIntegrityChecksToPullRequests < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :pull_requests, name: "index_pull_requests_on_release_id_and_phase", algorithm: :concurrently, if_exists: true
    add_index :pull_requests, [:release_id, :kind], unique: true, where: "kind = 'version_bump' AND state = 'open'", algorithm: :concurrently
    add_index :pull_requests, [:release_id, :phase], unique: true, where: "phase = 'pre_release' AND kind = 'version_bump'", algorithm: :concurrently
  end
end
