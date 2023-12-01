class AddVersioningStrategyToTrain < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :versioning_strategy, :string, default: "semver"
  end
end
