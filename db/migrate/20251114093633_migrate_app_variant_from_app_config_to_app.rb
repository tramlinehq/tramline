class MigrateAppVariantFromAppConfigToApp < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      # Add app_id column to app_variants (keeping app_config_id for now)
      add_reference :app_variants, :app, null: true, foreign_key: true, type: :uuid

      # Make app_config_id nullable (in preparation for removal)
      change_column_null :app_variants, :app_config_id, true

      # Add unique index for new app_id relationship (matching the old pattern)
      add_index :app_variants, [:bundle_identifier, :app_id], unique: true, name: "index_app_variants_on_bundle_identifier_and_app_id"
    end
  end
end
