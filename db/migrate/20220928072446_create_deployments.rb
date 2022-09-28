class CreateDeployments < ActiveRecord::Migration[7.0]
  def change
    create_table :deployments, id: :uuid do |t|
      t.belongs_to :integration, null: true, index: true, type: :uuid
      t.belongs_to :train_step, null: false, index: true, foreign_key: true, type: :uuid
      t.json :build_artifact_channel
      t.integer :deployment_number, default: 0, null: false, limit: 2 # smallint
      t.timestamps
    end
  end
end
