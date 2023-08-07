class AddAutomaticFlagToRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :releases, :is_automatic, :boolean, default: false
  end
end
