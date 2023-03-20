class MakeReleaseSuffixOptional < ActiveRecord::Migration[7.0]
  def change
    change_column_null :train_steps, :release_suffix, true
  end
end
