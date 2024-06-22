class AddPreProdRelease < ActiveRecord::Migration[7.0]
  def change
    create_table :pre_prod_releases, id: :uuid do |t|
      t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      t.references :build, null: true, index: true, foreign_key: true, type: :uuid
      t.string :type, null: false

      t.timestamps
    end
  end
end
