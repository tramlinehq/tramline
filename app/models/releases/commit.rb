class Releases::Commit < ApplicationRecord
  self.table_name = "releases_commits"

  belongs_to :train
  belongs_to :train_run, class_name: "Releases::Train::Run"
  has_many :step_runs, class_name: "Releases::Step::Run", dependent: :nullify

  validates :commit_hash, uniqueness: {scope: :train_run_id}
end
