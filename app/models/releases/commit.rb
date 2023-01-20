# == Schema Information
#
# Table name: releases_commits
#
#  id           :uuid             not null, primary key
#  author_email :string           not null
#  author_name  :string           not null
#  commit_hash  :string           not null, indexed => [train_run_id]
#  message      :string
#  timestamp    :datetime         not null
#  url          :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  train_id     :uuid             not null, indexed
#  train_run_id :uuid             not null, indexed => [commit_hash], indexed
#
class Releases::Commit < ApplicationRecord
  self.table_name = "releases_commits"

  include Passportable

  belongs_to :train
  belongs_to :train_run, class_name: "Releases::Train::Run"
  has_many :step_runs, class_name: "Releases::Step::Run", dependent: :nullify, foreign_key: "releases_commit_id", inverse_of: :commit
  has_many :sign_offs, foreign_key: "releases_commit_id", dependent: :destroy, inverse_of: :commit
  has_many :passports, as: :stampable, dependent: :destroy

  STAMPABLE_REASONS = ["created"]

  validates :commit_hash, uniqueness: { scope: :train_run_id }

  delegate :current_step, to: :train_run

  after_commit -> { create_stamp!(data: { sha: short_sha }) }, on: :create
  after_commit -> { trigger_step_runs }, on: :create

  def run_for(step)
    step_runs.where(step: step).last
  end

  def stale?
    train_run.commits.last != self
  end

  def short_sha
    commit_hash[0, 5]
  end

  private

  def trigger_step_run(step, sign_required)
    Triggers::StepRun.call(step, self, sign_required)
  end

  def trigger_step_runs
    train.ordered_steps_until(current_step).each do |step|
      if step.step_number < current_step
        trigger_step_run(step, false)
      else
        trigger_step_run(step, true)
      end
    end
  end
end
