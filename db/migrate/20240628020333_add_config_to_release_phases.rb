class AddConfigToReleasePhases < ActiveRecord::Migration[7.0]
  def change
    add_column :pre_prod_releases, :config, :jsonb, null: false, default: {}
    add_column :production_releases, :config, :jsonb, null: false, default: {}
  end
end
