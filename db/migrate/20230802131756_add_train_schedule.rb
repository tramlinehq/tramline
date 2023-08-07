class AddTrainSchedule < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :trains, bulk: true do |t|
        t.datetime :kickoff_at, null: true
        t.interval :repeat_duration, null: true
      end
    end
  end
end
