class CreateCrashlyticsIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :crashlytics_integrations, id: :uuid do |t|
      t.string :json_key
      t.string :project_number

      t.timestamps
    end
  end
end
