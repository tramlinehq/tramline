class CreateExternalApp < ActiveRecord::Migration[7.0]
  def change
    create_table :external_apps, id: :uuid do |t|
      t.belongs_to :app, null: false, index: true, foreign_key: true, type: :uuid

      t.timestamp :fetched_at, index: true
      t.jsonb :channel_data
      t.timestamps
    end
  end
end
