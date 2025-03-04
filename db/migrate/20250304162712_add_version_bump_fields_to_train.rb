class AddVersionBumpFieldsToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :version_bump_enabled, :boolean, default: false
    add_column :trains, :version_bump_file_paths, :string
  end
end
