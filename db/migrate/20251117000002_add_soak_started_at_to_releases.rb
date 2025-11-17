class AddSoakStartedAtToReleases < ActiveRecord::Migration[7.2]
  def change
    add_column :releases, :soak_started_at, :datetime
  end
end
