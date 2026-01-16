class CreateSentryIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :sentry_integrations, id: :uuid do |t|
      t.string :access_token
      t.jsonb :android_config
      t.jsonb :ios_config

      t.timestamps
    end
  end
end
