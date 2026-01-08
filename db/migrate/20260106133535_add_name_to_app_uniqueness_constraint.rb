class AddNameToAppUniquenessConstraint < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_index :apps, [:platform, :bundle_identifier, :organization_id],
        name: "index_apps_on_platform_and_bundle_id_and_org_id",
        if_exists: true

      add_index :apps, [:platform, :bundle_identifier, :organization_id, :name],
        name: "index_apps_on_platform_bundle_id_org_id_and_name",
        unique: true,
        algorithm: :concurrently
    end
  end
end
