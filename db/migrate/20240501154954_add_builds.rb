class AddBuilds < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    create_table :builds, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.belongs_to :commit, null: false, index: true, foreign_key: true, type: :uuid
      t.string :version_name
      t.string :build_number
      t.timestamp :generated_at
      t.timestamps
    end

    add_reference :build_artifacts, :build, type: :uuid, null: true, index: {algorithm: :concurrently}
  end
end
