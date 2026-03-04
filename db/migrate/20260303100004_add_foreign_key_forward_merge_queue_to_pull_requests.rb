class AddForeignKeyForwardMergeToPullRequests < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :pull_requests, :forward_merges, validate: false
  end
end
