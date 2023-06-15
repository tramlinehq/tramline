class RemoveUnusedColumnsFromReleasePlatform < ActiveRecord::Migration[7.0]
  def change
    change_column_null :release_platforms, :description, true
    change_column_null :release_platforms, :version_seeded_with, true

    change_column_null :release_platform_runs, :branch_name, true
    change_column_null :release_platform_runs, :release_version, true
  end
end
