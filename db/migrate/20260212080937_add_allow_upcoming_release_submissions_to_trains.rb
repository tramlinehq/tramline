class AddAllowUpcomingReleaseSubmissionsToTrains < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :allow_upcoming_release_submissions, :boolean, default: false, null: false
  end
end
