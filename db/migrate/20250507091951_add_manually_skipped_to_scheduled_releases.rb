class AddManuallySkippedToScheduledReleases < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_releases, :manually_skipped, :boolean, default: false
  end
end
