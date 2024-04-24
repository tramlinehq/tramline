class AddParentsToCommits < ActiveRecord::Migration[7.0]
  def change
    add_column :commits, :parents, :jsonb
  end
end
