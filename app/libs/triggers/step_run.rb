class Triggers::StepRun
  def self.call(step, commit, release_platform_run)
    new(step, commit, release_platform_run).call
  end

  def initialize(step, commit, release_platform_run)
    @step = step
    @release_platform_run = release_platform_run
    @commit = commit
  end

  # FIXME: should we take a lock around this release? what is someone double triggers the run?
  def call
    release_platform_run
      .step_runs
      .create!(step:, scheduled_at: Time.current, commit:, build_version:, sign_required: false)
  end

  private

  attr_reader :step, :release_platform_run, :commit

  def build_version
    version = release_platform_run.release_version
    version += "-" + step.release_suffix if step.release_suffix.present?
    version
  end
end
