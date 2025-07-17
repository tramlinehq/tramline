class SetDefaultReleaseBranchNamePattern < ActiveRecord::Migration[7.0]
  def up
    Train.where(release_branch_name_pattern: [nil, ""]).find_each do |train|
      train.update_column(:release_branch_name_pattern, "r/{{train_name}}/%Y-%m-%d")
    end
  end

  def down
    Train.update_all(release_branch_name_pattern: nil)
  end
end