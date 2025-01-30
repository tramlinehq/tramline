class CreateWorkflowConfigParameters < ActiveRecord::Migration[7.2]
  def change
    create_table :workflow_config_parameters do |t|
      t.string :name, null: false
      t.string :value, null: false
      t.references :workflow, null: false, foreign_key: {to_table: :workflow_configs}
      t.index [:workflow_id, :name], unique: true

      t.timestamps
    end
  end
end
