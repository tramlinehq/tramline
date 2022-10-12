class RemoveVersionSuffixFromTrain < ActiveRecord::Migration[7.0]
  def change
    remove_index :trains, column: [:version_suffix, :app_id]
    remove_column :trains, :version_suffix
  end
end
