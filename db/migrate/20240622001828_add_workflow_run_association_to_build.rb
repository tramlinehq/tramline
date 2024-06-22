class AddWorkflowRunAssociationToBuild < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_belongs_to :builds, :workflow_run, type: :uuid, null: true, index: true, foreign_key: true
    end
  end
end
