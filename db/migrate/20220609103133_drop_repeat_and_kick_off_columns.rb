class DropRepeatAndKickOffColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :trains, :kickoff_at, :datetime
    remove_column :trains, :repeat_duration, :intervel
  end
end
