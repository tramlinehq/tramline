class Coordinators::CreateBuild
  include Loggable

  def self.call(workflow_run, pre_prod_release)
    new(workflow_run, pre_prod_release).call
  end

  def initialize(workflow_run, pre_prod_release)
    @workflow_run = workflow_run
    @pre_prod_release = pre_prod_release
  end

  def call
    Build.find_or_create_by!(
      workflow_run: @workflow_run,
      release_platform_run: @pre_prod_release.release_platform_run,
      commit: @workflow_run.commit
    )

    @pre_prod_release.trigger_submissions!
  rescue => ex
    elog(ex)
    @pre_prod_release.fail!
  end
end
