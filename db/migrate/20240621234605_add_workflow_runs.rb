class AddWorkflowRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_runs, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :pre_prod_release, null: false, index: true, foreign_key: true, type: :uuid
      t.string :status, null: false
      t.jsonb :workflow_config
      t.string :build_number
      t.string :external_id
      t.string :external_url
      t.string :external_number
      t.string :artifacts_url
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
