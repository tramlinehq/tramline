class CreateAppConfig < ActiveRecord::Migration[7.0]
  def change
    create_table :app_configs, id: :uuid do |t|
      t.belongs_to :app, null: false, index: {unique: true}, foreign_key: true, type: :uuid
      t.json :code_repository
      t.json :notification_channel
      t.string :working_branch

      t.timestamps
    end
  end
end
