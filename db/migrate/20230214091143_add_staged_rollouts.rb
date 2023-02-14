class AddStagedRollouts < ActiveRecord::Migration[7.0]
  def change
    create_table :staged_rollouts, id: :uuid do |t|
      t.belongs_to :deployment_run, null: false, index: true, foreign_key: true, type: :uuid

      t.decimal :config, array: true, default: []
      t.string :status
      t.integer :current_stage
      t.timestamps
    end
  end
end
