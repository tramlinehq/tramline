class AddStoreRollouts < ActiveRecord::Migration[7.0]
  def change
    create_table :store_rollouts do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :build, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :store_submission, null: true, index: true, foreign_key: true, type: :uuid

      t.string :type, null: false
      t.string :status, null: false
      t.jsonb :release_channel, null: false

      t.integer :current_stage, limit: 2
      t.decimal :config, precision: 8, scale: 5, default: [], array: true, null: false

      t.timestamps
    end
  end
end
