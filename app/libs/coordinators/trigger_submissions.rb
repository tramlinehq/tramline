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
    workflow_run.build.attach_artifact!

    if workflow_run.release_candidate? && release_platform_run.hotfix?
      Coordinators::StartProductionRelease.call(release_platform_run, workflow_run.build.id)
    end

    workflow_run.triggering_release.trigger_submissions!
  rescue => ex
    elog(ex)
    workflow_run.triggering_release.fail!
  end

  attr_reader :workflow_run, :release_platform_run
end
