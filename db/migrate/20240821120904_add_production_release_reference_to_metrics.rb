class AddProductionReleaseReferenceToMetrics < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_column_null :release_health_metrics, :deployment_run_id, true
      add_reference :release_health_metrics, :production_release, foreign_key: {to_table: :production_releases}, null: true, type: :uuid
    end
  end
end
