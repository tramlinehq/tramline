class CreateDeploymentRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :deployment_runs, id: :uuid do |t|
      t.belongs_to :deployment, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :train_step_run, null: false, index: true, foreign_key: true, type: :uuid
      t.timestamp :scheduled_at, null: false
      t.string :status
      t.timestamps
    end
  end
end
