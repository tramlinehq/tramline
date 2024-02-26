class AddGithubLoginToUsers < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :users, bulk: true do |t|
        t.column :github_login, :string
        t.column :github_id, :string
      end
    end
  end
end
