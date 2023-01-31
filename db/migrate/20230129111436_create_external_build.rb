class CreateExternalBuild < ActiveRecord::Migration[7.0]
  def change
    create_table :external_builds, id: :uuid do |t|
      t.belongs_to :deployment_run, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name
      t.string :build_number
      t.string :status
      t.timestamp :added_at
      t.integer :size_in_bytes
      t.timestamps
    end
  end
end
