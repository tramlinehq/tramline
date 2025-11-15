class RemoveAppConfigForeignKeys < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      # Remove foreign key constraint from app_configs to apps
      remove_foreign_key :app_configs, :apps, if_exists: true
      
      # Remove foreign key constraint from app_variants to app_configs
      remove_foreign_key :app_variants, :app_configs, if_exists: true
    end
  end
end
