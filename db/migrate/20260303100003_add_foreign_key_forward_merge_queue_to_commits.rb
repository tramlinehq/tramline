class AddForeignKeyForwardMergeQueueToCommits < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :commits, :forward_merge_queues, validate: false
  end
end
