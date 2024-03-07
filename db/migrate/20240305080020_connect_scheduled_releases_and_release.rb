class ConnectScheduledReleasesAndRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :scheduled_releases, :release_id, :uuid, null: true
  end
end
