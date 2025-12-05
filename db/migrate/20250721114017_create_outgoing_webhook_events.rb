class CreateOutgoingWebhookEvents < ActiveRecord::Migration[7.2]
  def up
    drop_table :outgoing_webhooks, if_exists: true
    remove_index :outgoing_webhooks, :active, if_exists: true

    create_table :outgoing_webhook_events do |t|
      t.references :release, null: false, foreign_key: true, type: :uuid
      t.string :event_type, null: false
      t.datetime :event_timestamp, null: false
      t.string :status, null: false
      t.jsonb :event_payload, null: false
      t.jsonb :response_data
      t.text :error_message

      t.timestamps
    end

    add_index :outgoing_webhook_events, :status
    add_index :outgoing_webhook_events, :event_type
    add_index :outgoing_webhook_events, :event_timestamp
  end

  def down
    remove_index :outgoing_webhook_events, :status, if_exists: true
    remove_index :outgoing_webhook_events, :event_type, if_exists: true
    remove_index :outgoing_webhook_events, :event_timestamp, if_exists: true
    drop_table :outgoing_webhook_events, if_exists: true
  end
end
