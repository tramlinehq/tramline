class AddPlatformToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :platform, :string
  end
end
