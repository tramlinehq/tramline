class CreateGithubIntegration < ActiveRecord::Migration[7.0]
  def change
    create_table :github_integrations, id: :uuid do |t|
      t.string :installation_id

      t.timestamps
    end
  end
end
