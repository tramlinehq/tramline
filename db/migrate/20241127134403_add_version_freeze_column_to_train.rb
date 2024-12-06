class AddVersionFreezeColumnToTrain < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :freeze_version, :boolean, default: false
  end
end
