class AddTrainRunToCommits < ActiveRecord::Migration[7.0]
  def change
    add_reference :releases_commits, :train_run, null: false, foreign_key: true, type: :uuid
  end
end
