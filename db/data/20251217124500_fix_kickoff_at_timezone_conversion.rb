# frozen_string_literal: true

class FixKickoffAtTimezoneConversion < ActiveRecord::Migration[7.2]
  def up
    return
    # We need to convert them to local time components in each app's timezone.
    # Example:
    # If user entered 6:30 PM PST, it was previously stored as 02:30 UTC.
    # We want to convert it to a naive (utc) 18:30.
    Train.where.not(kickoff_at: nil).find_each do |train|
      timezone = train.app.timezone || "UTC"
      # kickoff_at currently has UTC time components stored as naive timestamp
      # Convert to local time in the app's timezone
      local_time = train.kickoff_at.in_time_zone("UTC").in_time_zone(timezone)

      # Store the local time components as naive timestamp
      naive_local = Time.utc(
        local_time.year,
        local_time.month,
        local_time.day,
        local_time.hour,
        local_time.min,
        local_time.sec
      )

      train.update_column(:kickoff_at, naive_local)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
