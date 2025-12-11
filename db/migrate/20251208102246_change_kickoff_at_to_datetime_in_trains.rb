class ChangeKickoffAtToDatetimeInTrains < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      # Add a temporary datetime column
      add_column :trains, :kickoff_datetime, :datetime

      # Convert time to datetime by combining with current date
      execute <<~SQL
        UPDATE trains 
        SET kickoff_datetime = CURRENT_DATE + kickoff_at
        WHERE kickoff_at IS NOT NULL
      SQL

      # Remove the time column
      remove_column :trains, :kickoff_at

      # Rename the datetime column to kickoff_at
      rename_column :trains, :kickoff_datetime, :kickoff_at
    end
  end

  def down
    safety_assured do
      # Add back time column
      add_column :trains, :kickoff_time, :time

      # Extract time from datetime
      execute <<~SQL
        UPDATE trains 
        SET kickoff_time = kickoff_at::time
        WHERE kickoff_at IS NOT NULL
      SQL

      # Remove datetime column
      remove_column :trains, :kickoff_at

      # Rename time column back
      rename_column :trains, :kickoff_time, :kickoff_at
    end
  end
end
