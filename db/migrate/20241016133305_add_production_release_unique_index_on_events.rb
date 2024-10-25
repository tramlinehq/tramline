class AddProductionReleaseUniqueIndexOnEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :release_health_events,
              [:deployment_run_id, :release_health_rule_id, :release_health_metric_id],
              unique: true,
              name: "idx_events_on_deployment_and_rule_and_metric"

    add_index :release_health_events,
              [:deployment_run_id, :release_health_rule_id, :release_health_metric_id],
              unique: true,
              where: "deployment_run_id IS NOT NULL",
              name: "idx_events_on_deployment_and_rule_and_metric",
              algorithm: :concurrently

    add_index :release_health_events,
              [:production_release_id, :release_health_rule_id, :release_health_metric_id],
              unique: true,
              where: "production_release_id IS NOT NULL",
              name: "idx_events_on_production_release_and_rule_and_metric",
              algorithm: :concurrently
  end
end
