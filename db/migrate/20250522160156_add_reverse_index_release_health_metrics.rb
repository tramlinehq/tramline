class AddReverseIndexReleaseHealthMetrics < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_index :release_health_metrics, [:production_release_id, :fetched_at], order: {fetched_at: :desc}, algorithm: :concurrently
  end
end
