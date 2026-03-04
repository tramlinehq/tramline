class ValidateForeignKeyForwardMergeOnCommits < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :commits, :forward_merges
  end
end
