class CreateTrainRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :train_releases, id: :uuid do |t|
      t.belongs_to :train, null: false, index: true, foreign_key: true, type: :uuid
      t.string :code_name, null: false
      t.timestamp :started_at, null: false
      t.string :status, null: false

      t.timestamps
    end
  end
end
