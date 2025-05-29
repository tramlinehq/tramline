class AddVersionBumpingStrateg < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :delete_me, :string
  end
end
