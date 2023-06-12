class Triggers::StepRun
  def self.call(step, commit, train_run)
    new(step, commit, train_run).call
  end

  def initialize(step, commit, train_run)
    @step = step
    @release = train_run
    @commit = commit
  end

  # FIXME: should we take a lock around this release? what is someone double triggers the run?
  def call
    release
      .step_runs
      .create!(step:, scheduled_at: Time.current, commit:, build_version:, sign_required: false)
      .trigger_ci!
  end

  private

  attr_reader :step, :release, :commit

  def build_version
    version = release.release_version
    version += "-" + step.release_suffix if step.release_suffix.present?
    version
  end
end
