class WorkflowProcessors::WorkflowRunV2
  include Memery
  GITHUB = WorkflowProcessors::Github::WorkflowRun
  BITRISE = WorkflowProcessors::Bitrise::WorkflowRun
  BITRISE_PIPELINE = WorkflowProcessors::Bitrise::PipelineRun
  BITBUCKET = WorkflowProcessors::Bitbucket::WorkflowRun
  GITLAB = WorkflowProcessors::Gitlab::WorkflowRun
  TEAMCITY = WorkflowProcessors::Teamcity::WorkflowRun

  class WorkflowRunUnknownStatus < StandardError; end

  def self.process(workflow_run)
    new(workflow_run).process
  end

  def initialize(workflow_run)
    @workflow_run = workflow_run
  end

  def process
    return re_enqueue if in_progress?
    update_status!
  end

  private

  def re_enqueue
    update_build_number_from_poll!
    WorkflowRuns::PollRunStatusJob.set(wait: wait_time).perform_async(workflow_run.id)
  end

  attr_reader :workflow_run
  delegate :in_progress?, :successful?, :failed?, :error?, :halted?, :artifacts_url, :started_at, :finished_at, to: :runner
  delegate :github_integration?, :bitrise_integration?, :bitbucket_integration?, :gitlab_integration?, :teamcity_integration?, to: :integration
  delegate :artifact_name_pattern, :app, to: :workflow_run

  def update_status!
    update_build_number_from_poll!

    if successful?
      workflow_run.add_metadata!(artifacts_url:, started_at:, finished_at:)
      workflow_run.finish!
    elsif error? && workflow_run.allow_error?
      workflow_run.add_metadata!(artifacts_url:, started_at:, finished_at:)
      workflow_run.finish!
    elsif error?
      workflow_run.fail!
    elsif failed?
      workflow_run.fail!
    elsif halted?
      workflow_run.halt!
    else
      raise WorkflowRunUnknownStatus
    end
  end

  memoize def runner
    return GITHUB.new(external_workflow_run) if github_integration?
    return BITRISE_PIPELINE.new(external_workflow_run) if bitrise_integration? && app.custom_bitrise_pipelines?
    return BITRISE.new(workflow_run.ci_cd_provider, external_workflow_run, artifact_name_pattern) if bitrise_integration?
    return BITBUCKET.new(external_workflow_run) if bitbucket_integration?
    return GITLAB.new(workflow_run.ci_cd_provider, external_workflow_run) if gitlab_integration?
    TEAMCITY.new(workflow_run.ci_cd_provider, external_workflow_run, artifact_name_pattern) if teamcity_integration?
  end

  def integration
    workflow_run.ci_cd_provider.integration
  end

  memoize def external_workflow_run
    workflow_run.get_external_run
  end

  # TeamCity may not return a build number at trigger time (shared counters,
  # snapshot dependencies). Pick it up during polling once TC has assigned it.
  # Dependency-chain builds may also surface unresolved template strings
  # (e.g. "%dep.OtherBuild.system.build.number%") while the parent build is
  # still running — skip those and wait for a numeric value.
  def update_build_number_from_poll!
    return unless app.build_number_managed_externally?
    return if workflow_run.external_unique_number.present?

    number = external_workflow_run&.with_indifferent_access&.dig(:number)
    return if number.blank?

    numeric_number = Integer(number, exception: false)
    return unless numeric_number

    workflow_run.update!(external_unique_number: number, external_number: number)
    workflow_run.build&.update!(build_number: number)
    app.bump_build_number!(release_version: workflow_run.build&.release_version, workflow_build_number: numeric_number)
  end

  def wait_time
    if Rails.env.development?
      1.minute
    else
      2.minutes
    end
  end
end
