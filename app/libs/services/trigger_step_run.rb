module Services
  class TriggerStepRun
    def self.call(step, commit)
      new(step, commit).call
    end

    def initialize(step, commit)
      @step = step
      @release = step.train.active_run
      @commit = commit
    end

    def call
      release.update(release_version: step.train.version_current)
      build_version = release.release_version + "-" + step.release_suffix
      build_number = step.train.app.bump_build_number!.to_s
      step_run = release.step_runs.create!(step:, scheduled_at: Time.current, status: "on_track", commit:, build_version:, build_number:)
      step_run.automatons!
    end

    private

    attr_reader :step, :release, :commit
  end
end
