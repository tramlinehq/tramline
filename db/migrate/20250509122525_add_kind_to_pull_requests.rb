class AddKindToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :pull_requests, :kind, :string, null: true
  end
end
