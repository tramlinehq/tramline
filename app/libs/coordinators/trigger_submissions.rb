class Coordinators::TriggerSubmissions
  include Loggable

  def self.call(workflow_run)
    new(workflow_run).call
  end

  def initialize(workflow_run)
    @workflow_run = workflow_run
    @release_platform_run = workflow_run.release_platform_run
  end

  def call
    return unless release_platform_run.on_track?

    # Attempt to attach artifact only if platform is android
    if release_platform_run.android?
      begin
        workflow_run.build.attach_artifact!
      rescue Installations::Error => ex
        if ex.reason == :artifact_not_found
          # We can ignore the error if we find the build is found in store
          workflow_run.build.mark_available_without_artifact
        else
          raise
        end
      end
    elsif release_platform_run.ios?
      # There are only two cases for platform - android/ios, keeping it elsif for clarity
      # We don't handle uploads for ios (yet?)
      workflow_run.build.mark_available_without_artifact
    end

    if workflow_run.release_candidate? && release_platform_run.hotfix?
      Coordinators::StartProductionRelease.call(release_platform_run, workflow_run.build.id)
    end

    workflow_run.triggering_release.trigger_submissions!
  end

  attr_reader :workflow_run, :release_platform_run
end
