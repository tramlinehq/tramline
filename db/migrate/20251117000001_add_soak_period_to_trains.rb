class AddSoakPeriodToTrains < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :soak_period_enabled, :boolean, default: false, null: false
    add_column :trains, :soak_period_hours, :integer, default: 24
  end
end
