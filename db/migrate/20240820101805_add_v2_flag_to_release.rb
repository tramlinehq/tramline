class AddV2FlagToRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :releases, :is_v2, :boolean, default: false
  end
end
