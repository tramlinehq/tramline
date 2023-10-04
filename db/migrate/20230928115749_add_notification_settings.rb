class AddNotificationSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :notification_settings, id: :uuid do |t|
      t.belongs_to :train, null: false, index: true, foreign_key: true, type: :uuid

      t.string :kind, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :notification_channels
      t.jsonb :user_groups
      t.timestamps
    end

    add_index :notification_settings, [:train_id, :kind], unique: true
  end
end
