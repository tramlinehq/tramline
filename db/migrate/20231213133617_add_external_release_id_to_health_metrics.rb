class AddExternalReleaseIdToHealthMetrics < ActiveRecord::Migration[7.0]
  def change
    add_column :release_health_metrics, :external_release_id, :string, null: true
  end
end
