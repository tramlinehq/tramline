class AddStopOnFailureOnTrains < ActiveRecord::Migration[7.0]
  def change
    add_column :trains, :stop_automatic_releases_on_failure, :boolean, default: false, null: false
  end
end
