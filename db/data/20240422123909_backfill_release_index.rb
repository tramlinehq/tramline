# frozen_string_literal: true

class BackfillReleaseIndex < ActiveRecord::Migration[7.0]
  def up
    Train.all.each do |train|
      next if train.release_index.present?

      train.create_release_index
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
