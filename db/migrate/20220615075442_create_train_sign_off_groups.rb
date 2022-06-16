class CreateTrainSignOffGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :train_sign_off_groups, id: :uuid do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.references :sign_off_group, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
