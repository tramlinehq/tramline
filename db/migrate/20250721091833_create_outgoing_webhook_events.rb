class CreateOutgoingWebhookEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :outgoing_webhook_events, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.references :outgoing_webhook, null: false, foreign_key: true, type: :uuid
      t.datetime :event_timestamp, null: false
      t.string :status, null: false
      t.text :response_data
      t.text :error_message

      t.timestamps
    end
    
    add_index :outgoing_webhook_events, :event_timestamp
    add_index :outgoing_webhook_events, :status
    add_index :outgoing_webhook_events, [:train_id, :event_timestamp]
    add_index :outgoing_webhook_events, [:outgoing_webhook_id, :event_timestamp]
  end
end
