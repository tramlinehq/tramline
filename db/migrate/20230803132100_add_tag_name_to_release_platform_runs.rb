class AddTagNameToReleasePlatformRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :releases, :tag_name, :string
    add_column :release_platform_runs, :tag_name, :string
  end
end
