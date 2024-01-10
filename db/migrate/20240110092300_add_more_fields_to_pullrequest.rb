class AddMoreFieldsToPullrequest < ActiveRecord::Migration[7.0]
  def change
    add_column :pull_requests, :labels, :jsonb
  end
end
