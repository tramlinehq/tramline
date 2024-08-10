class Coordinators::TriggerSubmissions
  include Loggable

  def self.call(workflow_run)
    new(workflow_run).call
  end

  def initialize(workflow_run)
    @workflow_run = workflow_run
  end

  def call
    workflow_run.build.attach_artifact!
    workflow_run.triggering_release.trigger_submissions!
  rescue => ex
    elog(ex)
    workflow_run.triggering_release.fail!
  end

  attr_reader :workflow_run
end
