class AddBuildToExternalBuilds < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    change_column_null :external_builds, :step_run_id, true
    add_reference :external_builds, :build, type: :uuid, null: true, index: false

    remove_index :external_builds, column: :step_run_id, name: "index_external_builds_on_step_run_id", algorithm: :concurrently, if_exists: true
    add_index :external_builds, :step_run_id, unique: true, where: "step_run_id IS NOT NULL", name: "index_external_builds_on_step_run_id", algorithm: :concurrently
    add_index :external_builds, :build_id, unique: true, where: "build_id IS NOT NULL", name: "index_external_builds_on_build_id", algorithm: :concurrently
  end
end
