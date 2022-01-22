class CreateIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :integrations, id: :uuid do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.belongs_to :app, index: true, foreign_key: true, type: :uuid
      t.string :authorization_token
      t.string :original_authorization_token

      t.timestamps
    end
  end
end
