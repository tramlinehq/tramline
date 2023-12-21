class AddAppVariants < ActiveRecord::Migration[7.0]
  def change
    create_table :app_variants, id: :uuid do |t|
      t.belongs_to :app_config, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :bundle_identifier, null: false
      t.jsonb :firebase_ios_config, null: true
      t.jsonb :firebase_android_config, null: true

      t.timestamps
    end

    add_index :app_variants, [:bundle_identifier, :app_config_id], unique: true
  end
end
