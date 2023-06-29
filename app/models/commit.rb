# == Schema Information
#
# Table name: commits
#
#  id                      :uuid             not null, primary key
#  author_email            :string           not null
#  author_name             :string           not null
#  commit_hash             :string           not null, indexed => [release_id]
#  message                 :string
#  timestamp               :datetime         not null
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_id              :uuid             indexed => [commit_hash]
#  release_platform_id     :uuid             indexed
#  release_platform_run_id :uuid             indexed
#
class Commit < ApplicationRecord
  include Passportable

  has_many :step_runs, dependent: :nullify, inverse_of: :commit
  has_many :passports, as: :stampable, dependent: :destroy
  belongs_to :release, inverse_of: :commits

  STAMPABLE_REASONS = ["created"]

  validates :commit_hash, uniqueness: {scope: :release_id}

  after_commit -> { create_stamp!(data: {sha: short_sha}) }, on: :create
  after_commit :trigger_step_runs, on: :create

  delegate :release_platform_runs, to: :release

  scope :only_with_step_runs, -> { joins(:step_runs).distinct }
  scope :with_no_step_runs, -> { where.not(id: StepRun.select(:commit_id).distinct) }

  def run_for(step, release_platform_run)
    step_runs.where(step:, release_platform_run:).last
  end

  def stale?
    release.commits.only_with_step_runs.last != self
  end

  def short_sha
    commit_hash[0, 7]
  end

  def release_in_production
    release.production_release_started?
  end

  def step_runs_for(platform_run)
    step_runs.where(release_platform_run: platform_run).includes(:step).order(:created_at)
  end

  def trigger_step_runs_for(platform_run)
    platform_run.release_platform.ordered_steps_until(platform_run.current_step_number).each do |step|
      Triggers::StepRun.call(step, self, platform_run)
    end
  end

  private

  def trigger_step_runs
    release_platform_runs.reject(&:production_release_started?).each do |run|
      trigger_step_runs_for(run)
    end
  end
end
