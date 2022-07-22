module Services
  class TriggerStepRun
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
      build_version = release.release_version + "-" + step.release_suffix
      build_number = step.train.app.bump_build_number!.to_s
      step_run = release.step_runs.create!(step:, scheduled_at: Time.current, status: "on_track", commit:, build_version:, build_number:, sign_required:)
      step_run.automatons!
    end

    private

    attr_reader :step, :release, :commit, :sign_required
  end
end
