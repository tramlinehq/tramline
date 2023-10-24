class AddReleaseHealthMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :release_health_metrics, id: :uuid do |t|
      t.belongs_to :deployment_run, null: false, index: true, foreign_key: true, type: :uuid

      t.bigint :sessions
      t.bigint :sessions_in_last_day
      t.bigint :sessions_with_errors
      t.bigint :daily_users
      t.bigint :daily_users_with_errors
      t.bigint :errors
      t.bigint :new_errors
      t.datetime :fetched_at, null: false, index: true

      t.timestamps
    end
  end
end
