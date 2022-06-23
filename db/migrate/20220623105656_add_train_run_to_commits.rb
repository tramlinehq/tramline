class AddTrainRunToCommits < ActiveRecord::Migration[7.0]
  def change
    add_reference :releases_commits, :train_runs, null: false, foreign_key: true, type: :uuid
  end
end
