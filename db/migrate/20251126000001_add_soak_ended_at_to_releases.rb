class AddSoakEndedAtToReleases < ActiveRecord::Migration[7.2]
  def change
    add_column :releases, :soak_ended_at, :datetime
    add_column :releases, :soak_period_hours, :integer
  end
end