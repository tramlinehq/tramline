class CreateBitriseIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :bitrise_integrations, id: :uuid do |t|
      t.string :access_token

      t.timestamps
    end
  end
end
