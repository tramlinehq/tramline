class CreateOutgoingWebhooks < ActiveRecord::Migration[7.2]
  def change
    create_table :outgoing_webhooks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :train, null: false, foreign_key: true, type: :uuid
      t.string :url, null: false
      t.text :event_types, array: true, default: []
      t.text :description
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :outgoing_webhooks, :active
  end
end
