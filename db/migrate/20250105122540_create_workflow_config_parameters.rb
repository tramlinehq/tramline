class CreateWorkflowConfigParameters < ActiveRecord::Migration[7.2]
  def change
    create_table :workflow_config_parameters do |t|
      t.string :name
      t.string :value
      t.references :workflow, null: false, foreign_key: {to_table: :workflow_configs}

      t.timestamps
    end
  end
end
