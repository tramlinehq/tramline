class AddConfigToReleasePlatformRun < ActiveRecord::Migration[7.0]
  def change
    add_column :release_platforms, :config, :jsonb, null: true
    add_column :release_platform_runs, :config, :jsonb, null: true
  end
end
