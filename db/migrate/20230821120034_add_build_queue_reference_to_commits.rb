class AddBuildQueueReferenceToCommits < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_reference :commits, :build_queue, foreign_key: true, type: :uuid, null: true
    end
  end
end
