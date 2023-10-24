class ChangeReleaseHealthMetricsErrorsColumn < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      rename_column :release_health_metrics, :errors, :errors_count
      rename_column :release_health_metrics, :new_errors, :new_errors_count
    end
  end
end
