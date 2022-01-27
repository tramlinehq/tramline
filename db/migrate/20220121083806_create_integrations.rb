class CreateIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :integrations, id: :uuid do |t|
      t.belongs_to :app, null: false, index: true, foreign_key: true, type: :uuid

      t.string :category, null: false
      t.string :provider, null: false
      t.string :active_repo
      t.string :installation_id

      t.timestamps
    end
  end
end
