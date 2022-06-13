class CreateSignOffGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :sign_off_groups, id: :uuid do |t|
      t.string :name
      t.references :app, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
