class Releases::Commit < ApplicationRecord
  self.table_name = "releases_commits"

  belongs_to :train
  belongs_to :train_run, class_name: "Releases::Train::Run"
  has_many :step_runs, class_name: "Releases::Step::Run", dependent: :nullify, foreign_key: "releases_commit_id", inverse_of: :commit
  has_many :sign_offs, foreign_key: "releases_commit_id", dependent: :destroy, inverse_of: :commit

  validates :commit_hash, uniqueness: {scope: :train_run_id}

  def step_runs_for(step)
    step_runs.where(step: step)
  end

  def stale?
    train_run.commits.last != self
  end
end
