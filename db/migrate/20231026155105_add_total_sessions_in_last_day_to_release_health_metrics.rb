class AddTotalSessionsInLastDayToReleaseHealthMetrics < ActiveRecord::Migration[7.0]
  def change
    add_column :release_health_metrics, :total_sessions_in_last_day, :bigint
  end
end
