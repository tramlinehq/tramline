class CreateLifecycleHooks < ActiveRecord::Migration[7.2]
  def change
    create_table :lifecycle_hooks, id: :uuid do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.string :event, null: false
      t.string :name, null: false
      t.string :http_method, null: false
      t.string :url, null: false
      t.jsonb :headers, default: {}, null: false
      t.text :body_template
      t.jsonb :static_variables, default: {}, null: false
      t.string :auth_type, default: "none", null: false
      t.string :auth_username
      t.string :auth_secret
      t.boolean :notify_on_failure, default: true, null: false
      t.text :failure_message_template
      t.jsonb :failure_notification_channel
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :lifecycle_hooks, [:train_id, :event]
    add_index :lifecycle_hooks, [:train_id, :event, :active]
  end
end
