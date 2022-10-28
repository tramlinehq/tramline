class Releases::Commit < ApplicationRecord
  self.table_name = "releases_commits"

  include Passportable

  belongs_to :train
  belongs_to :train_run, class_name: "Releases::Train::Run"
  has_many :step_runs, class_name: "Releases::Step::Run", dependent: :nullify, foreign_key: "releases_commit_id", inverse_of: :commit
  has_many :sign_offs, foreign_key: "releases_commit_id", dependent: :destroy, inverse_of: :commit
  has_many :passports, as: :stampable, dependent: :destroy

  STAMPABLE_REASONS = ["created"]

  after_commit -> { create_stamp!(data: { sha: commit_hash }) }, on: :create
  validates :commit_hash, uniqueness: { scope: :train_run_id }

  def step_runs_for(step)
    step_runs.where(step: step)
  end

  def stale?
    train_run.commits.last != self
  end

  def short_sha
    commit_hash[0, 5]
  end
end
