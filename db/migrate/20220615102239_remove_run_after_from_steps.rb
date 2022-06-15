class RemoveRunAfterFromSteps < ActiveRecord::Migration[7.0]
  def change
    remove_column :train_steps, :run_after_duration, :intervel
  end
end
