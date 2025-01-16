class AddBuildSuffixes < ActiveRecord::Migration[7.2]
  def change
    add_column :workflow_configs, :build_suffix, :string, null: true
  end
end
