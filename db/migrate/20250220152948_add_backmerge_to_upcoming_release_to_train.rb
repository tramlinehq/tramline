class AddBackmergeToUpcomingReleaseToTrain < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :backmerge_to_upcoming_release, :boolean, default: false
  end
end
