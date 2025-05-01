class CommitOptionallyBelongsToReleaseChangelog < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_reference :commits,
                    :release_changelog,
                    type: :uuid, foreign_key: true, null: true, index: { algorithm: :concurrently }
      remove_index :commits, column: [:commit_hash, :release_id], unique: true, algorithm: :concurrently, if_exists: true
      add_index :commits, [:commit_hash, :release_id, :release_changelog_id], unique: true, algorithm: :concurrently
    end
  end
end
