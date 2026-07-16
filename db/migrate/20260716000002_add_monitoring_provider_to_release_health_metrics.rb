class AddMonitoringProviderToReleaseHealthMetrics < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :release_health_metrics, :monitoring_provider_type, :string
    add_column :release_health_metrics, :monitoring_provider_id, :uuid
    add_index :release_health_metrics,
      [:production_release_id, :monitoring_provider_type, :fetched_at],
      name: "idx_health_metrics_on_prod_release_provider_fetched",
      algorithm: :concurrently
  end
end
