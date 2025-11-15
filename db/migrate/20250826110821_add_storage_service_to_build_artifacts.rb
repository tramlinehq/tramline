class AddStorageServiceToBuildArtifacts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :build_artifacts, :storage_service, :string
    add_index :build_artifacts, :storage_service, algorithm: :concurrently
  end
end
