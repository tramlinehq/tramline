class ImproveBundleIdentifierIndexOnApp < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    remove_index :apps, [:bundle_identifier, :organization_id], if_exists: true
    add_index :apps, [:platform, :bundle_identifier, :organization_id], name: "index_apps_on_platform_and_bundle_id_and_org_id", unique: true, algorithm: :concurrently
  end
end
