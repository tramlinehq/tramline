# frozen_string_literal: true

class UpdateVersionBumpingStrategies < ActiveRecord::Migration[7.2]
  def up
    return
    Train.where(version_bump_enabled: true).find_each do |train|
      train.version_bump_strategy = Train.version_bump_strategies[:current_version_before_release_branch]
      train.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
