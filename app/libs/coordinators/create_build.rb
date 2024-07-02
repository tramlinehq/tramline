class Coordinators::CreateBuild
  include Loggable

  def self.call(workflow_run)
    new(workflow_run).call
  end

  def initialize(workflow_run)
    @workflow_run = workflow_run
  end

  def call
    build = Build.find_or_create_by!(
      workflow_run: @workflow_run,
      release_platform_run: @workflow_run.release_platform_run,
      commit: @workflow_run.commit,
      build_number: @workflow_run.build_number,
      version_name: @workflow_run.release_version
    )

    @workflow_run.triggering_release.trigger_submissions!(build)
  rescue => ex
    elog(ex)
    @workflow_run.triggering_release.fail!
  end
end
