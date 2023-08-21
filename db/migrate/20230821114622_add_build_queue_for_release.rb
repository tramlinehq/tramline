class AddBuildQueueForRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :build_queues, id: :uuid do |t|
      t.references :release, null: false, foreign_key: true, type: :uuid
      t.datetime :scheduled_at, null: false
      t.datetime :applied_at
      t.boolean :is_active, default: true

      t.timestamps
    end
  end
end
