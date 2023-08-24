class AddBuildQueueConfigOnTrain < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :trains, bulk: true do |t|
        t.column :build_queue_enabled, :boolean, default: false
        t.column :build_queue_wait_time, :interval
        t.column :build_queue_size, :integer, limit: 2
      end
    end
  end
end
