class AddReleaseHealthEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :release_health_events, id: :uuid do |t|
      t.belongs_to :deployment_run, null: false, foreign_key: true, type: :uuid
      t.belongs_to :release_health_rule, null: false, foreign_key: true, type: :uuid
      t.belongs_to :release_health_metric, null: false, foreign_key: true, type: :uuid

      t.string :health_status, null: false
      t.datetime :event_timestamp, null: false, index: true
      t.boolean :notification_triggered, default: false
      t.boolean :action_triggered, default: false

      t.timestamps
    end

    add_index :release_health_events,
      [:deployment_run_id, :release_health_rule_id, :release_health_metric_id],
      unique: true,
      name: "idx_events_on_deployment_and_rule_and_metric"
  end
end
