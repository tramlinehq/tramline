class AddBuildNumberFlagToApp < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :build_number_managed_internally, :boolean, default: true, null: false
  end
end
