class AddBuildSuffixes < ActiveRecord::Migration[7.2]
  def change
    add_column :workflow_configs, :build_suffix, :string, null: true
    add_column :release_step_configs, :build_suffix_for_release_version, :boolean, default: false
  end
end
