# frozen_string_literal: true

class ChangeKickoffAtToKickoffTime < ActiveRecord::Migration[7.0]
  def up
    # Step 1: Add new kickoff_time column (time without timezone)
    add_column :trains, :kickoff_time, :time

    # Step 2: Migrate existing data
    # Convert kickoff_at (UTC datetime) to time in app's timezone
    reversible do |dir|
      dir.up do
        Train.reset_column_information
        Train.find_each do |train|
          next if train.kickoff_at.blank?

          # Convert kickoff_at (UTC) to app's timezone and extract time component
          time_in_app_tz = train.kickoff_at.in_time_zone(train.app.timezone)
          train.update_column(:kickoff_time, time_in_app_tz.strftime("%H:%M:%S"))
        end
      end
    end

    # Step 3: Remove old column
    safety_assured { remove_column :trains, :kickoff_at }
  end

  def down
    # Add back the datetime column
    add_column :trains, :kickoff_at, :datetime

    # Attempt to reverse the migration
    # Note: We can't perfectly reverse since we lose the date component
    # We'll set it to the next occurrence from now
    reversible do |dir|
      dir.down do
        Train.reset_column_information
        Train.find_each do |train|
          next if train.kickoff_time.blank?

          # Set to next occurrence from now in app's timezone
          tz = train.app.timezone
          now = Time.current.in_time_zone(tz)
          kickoff_today = tz.parse("#{now.to_date} #{train.kickoff_time}")
          kickoff_datetime = kickoff_today > now ? kickoff_today : kickoff_today + 1.day

          train.update_column(:kickoff_at, kickoff_datetime.utc)
        end
      end
    end

    # Remove the time column
    safety_assured { remove_column :trains, :kickoff_time }
  end
end
