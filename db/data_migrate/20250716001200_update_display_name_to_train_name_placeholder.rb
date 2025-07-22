class UpdateDisplayNameToTrainNamePlaceholder < ActiveRecord::Migration[7.0]
  def up
    Train.where("release_branch_name_pattern LIKE '%{{display_name}}%'").find_each do |train|
      updated_pattern = train.release_branch_name_pattern.gsub("{{display_name}}", "{{train_name}}")
      train.update_column(:release_branch_name_pattern, updated_pattern)
    end
  end

  def down
    Train.where("release_branch_name_pattern LIKE '%{{train_name}}%'").find_each do |train|
      updated_pattern = train.release_branch_name_pattern.gsub("{{train_name}}", "{{display_name}}")
      train.update_column(:release_branch_name_pattern, updated_pattern)
    end
  end
end
