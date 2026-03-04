class AddForeignKeyForwardMergeToCommits < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :commits, :forward_merges, validate: false
  end
end
