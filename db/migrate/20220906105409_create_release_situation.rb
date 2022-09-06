class CreateReleaseSituation < ActiveRecord::Migration[7.0]
  def change
    create_table :release_situations, id: :uuid do |t|
      t.references :build_artifact, null: false, index: true, foreign_key: true, type: :uuid
      t.string :status

      t.timestamps
    end
  end
end
