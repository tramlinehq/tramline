class ChangeDescriptionToNullable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :trains, :description, false
    change_column_null :train_steps, :description, false
  end
end
