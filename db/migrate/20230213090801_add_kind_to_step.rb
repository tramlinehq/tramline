class AddKindToStep < ActiveRecord::Migration[7.0]
  def change
    add_column :train_steps, :kind, :string
  end
end
