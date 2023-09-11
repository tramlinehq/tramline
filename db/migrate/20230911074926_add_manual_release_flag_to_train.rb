class AddManualReleaseFlagToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :manual_release, :boolean, default: false
  end
end
