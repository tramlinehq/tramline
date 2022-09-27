class Triggers::StepRun
  delegate :transaction, to: ActiveRecord::Base

  def self.call(step, commit, sign_required = true)
    new(step, commit, sign_required).call
  end

  def initialize(step, commit, sign_required)
    @step = step
    @release = step.train.active_run
    @commit = commit
    @sign_required = sign_required
  end

  def call
    release.update(release_version: step.train.version_current)
    release.step_runs.create!(step:, scheduled_at: Time.current, commit:, build_version:, build_number:, sign_required:)
  end

  private

  attr_reader :step, :release, :commit, :sign_required

  def build_version
    release.release_version + "-" + step.release_suffix
  end

  def build_number
    step.train.app.bump_build_number!
  end
end
