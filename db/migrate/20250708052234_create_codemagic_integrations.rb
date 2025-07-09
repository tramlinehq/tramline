class CreateCodemagicIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :codemagic_integrations, id: :uuid do |t|
      t.string :access_token

      t.timestamps
    end
  end
end
