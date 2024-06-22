class AddWorkflowRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_runs, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :pre_prod_release, null: false, index: true, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
