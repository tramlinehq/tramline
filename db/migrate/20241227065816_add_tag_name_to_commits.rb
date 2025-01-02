class AddTagNameToCommits < ActiveRecord::Migration[7.2]
  def change
    add_column :commits, :tag_name, :string
  end
end
