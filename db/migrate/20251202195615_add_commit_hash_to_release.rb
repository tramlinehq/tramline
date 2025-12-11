class AddCommitHashToRelease < ActiveRecord::Migration[7.2]
  def change
    add_column :releases, :commit_hash, :string
  end
end
