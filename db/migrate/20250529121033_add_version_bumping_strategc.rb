class AddVersionBumpingStrategc < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :delete_me_to, :string
  end
end
