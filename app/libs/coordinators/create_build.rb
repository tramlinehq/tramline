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
    return if @pre_prod_release.build.present?

    build = Build.find_or_create_by!(
      workflow_run: @workflow_run,
      release_platform_run: @pre_prod_release.release_platform_run,
      commit: @workflow_run.commit
    )

    @pre_prod_release.attach_build!(build)
    @pre_prod_release.trigger_submission!
  rescue => ex
    elog(ex)
    @pre_prod_release.build_upload_failed!
  end
end
