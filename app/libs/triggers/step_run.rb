class Triggers::StepRun
  def self.call(step, commit, sign_required = true)
    new(step, commit, sign_required).call
  end

  def initialize(step, commit, sign_required)
    @step = step
    @release = step.train.active_run
    @commit = commit
    @sign_required = sign_required
  end

  # FIXME: should we take a lock around this release? what is someone double triggers the run?
  def call
    release
      .step_runs
      .create!(step:, scheduled_at: Time.current, commit:, build_version:, sign_required:)
      .then(&:trigger_ci!)
  end

  private

  attr_reader :step, :release, :commit, :sign_required

  def build_version
    release.release_version + "-" + step.release_suffix
  end
end
