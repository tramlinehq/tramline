class AddBranchPrefixColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :version_bump_branch_prefix, :string
    add_column :trains, :continuous_backmerge_branch_prefix, :string
  end
end
