class FixTypoInTheTableName < ActiveRecord::Migration[7.0]
  def up
    return unless connection.data_source_exists?('releases_commit_listners')

    rename_table :releases_commit_listners, :releases_commit_listeners
  end

  def down
    return unless connection.data_source_exists?('releases_commit_listeners')

    rename_table :releases_commit_listeners, :releases_commit_listners
  end
end
