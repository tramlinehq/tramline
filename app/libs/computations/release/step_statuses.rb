class Computations::Release::StepStatuses
  using RefinedArray
  STATUS = [:blocked, :ongoing, :success, :none].zip_map_self

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    {
      overview: STATUS[:none],
      changeset_tracking: changeset_tracking_status,
      internal_builds: internal_builds_status,
      regression_testing: internal_builds_status,
      release_candidate: release_candidate_status,
      soak_period: soak_period_status,
      notes: notes_status,
      screenshots: STATUS[:none],
      approvals: STATUS[:none],
      app_submission: app_submission_status,
      rollout_to_users: rollout_to_users_status
    }
  end

  def changeset_tracking_status
    return STATUS[:ongoing] if @release.applied_commits != @release.all_commits
    STATUS[:success]
  end

  def internal_builds_status
    return STATUS[:none] if @release.release_platform_runs.all? { |rp| rp.steps.review.blank? }
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.step_runs.any? { |sr| sr.step.review? && sr.active? } }
    STATUS[:success]
  end

  def release_candidate_status
    return STATUS[:none] if @release.release_platform_runs.all? { |rp| rp.step_runs_for(rp.release_platform.release_step).blank? }
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.step_runs.any? { |sr| sr.step.release? && sr.active? && !sr.production_release_submitted? } }
    STATUS[:success]
  end

  def soak_period_status
    return STATUS[:blocked] if release_candidate_status == STATUS[:none]
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.step_runs.any? { |sr| sr.step.release? && sr.deployment_started? && !sr.production_release_submitted? } }
    STATUS[:success]
  end

  def notes_status
    return STATUS[:ongoing] unless production_release_submitted?
    STATUS[:success]
  end

  def approval_status
    return STATUS[:success] if @release.finished? || production_release_submitted?
    STATUS[:ongoing]
  end

  def app_submission_status
    return STATUS[:blocked] unless @release.release_platform_runs.any? { |rp| rp.step_runs.any? { |sr| sr.step.release? && !sr.status.in?(StepRun::WORKFLOW_NOT_STARTED + StepRun::WORKFLOW_IN_PROGRESS) } }
    return STATUS[:ongoing] unless production_release_submitted?
    STATUS[:success]
  end

  def rollout_to_users_status
    return STATUS[:blocked] if app_submission_status == STATUS[:blocked]
    return STATUS[:ongoing] unless @release.production_release_happened?
    return STATUS[:blocked] unless production_release_submitted?
    STATUS[:success]
  end

  private

  def production_release_submitted?
    @release.release_platform_runs.any?(&:production_release_submitted?)
  end
end
