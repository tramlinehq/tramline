class MigrateAppVariantsToAppAssociation < ActiveRecord::Migration[7.2]
  def change
    add_reference :app_variants, :app, type: :uuid, null: false, foreign_key: true
    
    # Populate app_id from app_config association
    execute <<-SQL
      UPDATE app_variants 
      SET app_id = app_configs.app_id
      FROM app_configs
      WHERE app_variants.app_config_id = app_configs.id;
    SQL
    
    # Remove the old app_config association
    remove_reference :app_variants, :app_config, type: :uuid, foreign_key: true
    remove_index :app_variants, [:bundle_identifier, :app_config_id] if index_exists?(:app_variants, [:bundle_identifier, :app_config_id])
    add_index :app_variants, [:bundle_identifier, :app_id], unique: true
  end
end