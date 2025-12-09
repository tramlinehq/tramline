class ChangeKickoffAtToTimeInTrains < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      # Convert existing UTC datetimes to naive local datetimes
      # This extracts the local time component and stores it without timezone info
      execute <<~SQL
        UPDATE trains 
        SET kickoff_at = (kickoff_at AT TIME ZONE 'UTC')::timestamp
        WHERE kickoff_at IS NOT NULL
      SQL
    end
  end

  def down
    # This is lossy - we can't perfectly recreate the original UTC times
    # But we can convert back to UTC assuming current timezone
    safety_assured do
      execute <<~SQL
        UPDATE trains 
        SET kickoff_at = kickoff_at AT TIME ZONE 'UTC'
        WHERE kickoff_at IS NOT NULL
      SQL
    end
  end
end
