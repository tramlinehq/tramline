class AddPlayStoreSubmissionsBlockedToReleasePlatformRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :release_platform_runs, :play_store_blocked, :boolean, default: false
  end
end
