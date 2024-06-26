class AddPatchVersionBumpOnlyOnTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :patch_version_bump_only, :boolean, default: false, null: false
  end
end
