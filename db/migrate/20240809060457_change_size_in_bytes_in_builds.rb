class ChangeSizeInBytesInBuilds < ActiveRecord::Migration[7.0]
  def up
    safety_assured { change_column :builds, :size_in_bytes, :bigint }
  end

  def down
    change_column :builds, :size_in_bytes, :integer
  end
end
