class AddVersionBumpingStrategies < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :version_bump_strategy, :string, null: true
  end
end
