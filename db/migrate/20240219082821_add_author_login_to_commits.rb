class AddAuthorLoginToCommits < ActiveRecord::Migration[7.0]
  def change
    add_column :commits, :author_login, :string
  end
end
