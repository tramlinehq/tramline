# frozen_string_literal: true

class UpdateNewTagConfigs < ActiveRecord::Migration[7.2]
  def up
    return
    Train.all.find_each do |train|
      train.update(tag_end_of_release_vcs_release: train.tag_end_of_release?)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
