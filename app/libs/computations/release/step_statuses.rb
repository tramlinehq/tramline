class Computations::Release::StepStatuses
  using RefinedArray
  STATUS = [:blocked, :ongoing, :success, :none].zip_map_self
  PHASES = [:completed, :kickoff, :stabilization, :review, :rollout, :finishing].zip_map_self

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    {
      statuses: {
        overview: STATUS[:success],
        changeset_tracking: changeset_tracking_status,
        internal_builds: internal_builds_status,
        regression_testing: STATUS[:blocked],
        release_candidate: release_candidate_status,
        soak_period: STATUS[:blocked],
        notes: notes_status,
        screenshots: STATUS[:blocked],
        approvals: STATUS[:blocked],
        app_submission: app_submission_status,
        rollout_to_users: rollout_to_users_status
      },
      current_overall_status: current_overall_status
    }
  end

  def changeset_tracking_status
    return STATUS[:ongoing] if new_change?
    STATUS[:success]
  end

  def internal_builds_status
    return STATUS[:none] if @release.release_platform_runs.all? { |rp| rp.internal_builds.none? }
    return STATUS[:ongoing] if new_change?
    STATUS[:success]
  end

  def release_candidate_status
    return STATUS[:none] if @release.release_platform_runs.all? { |rp| rp.latest_beta_release.blank? }
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.latest_beta_release.actionable? }
    STATUS[:success]
  end

  def notes_status
    return STATUS[:ongoing] unless @release.finished?
    STATUS[:success]
  end

  def app_submission_status
    return STATUS[:blocked] if @release.release_platform_runs.all? { |rp| rp.production_releases.none? }
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.inflight_production_release.present? }
    STATUS[:success]
  end

  def rollout_to_users_status
    return STATUS[:blocked] if @release.release_platform_runs.all? { |rp| rp.production_store_rollouts.none? }
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.active_store_rollout&.present? }
    return STATUS[:ongoing] if @release.release_platform_runs.any? { |rp| rp.inflight_store_rollout&.present? }
    STATUS[:success]
  end

  def current_overall_status
    return PHASES[:completed] if @release.finished?
    return PHASES[:finishing] if Release::POST_RELEASE_STATES.include?(@release.status)
    return PHASES[:rollout] if @release.release_platform_runs.any? { |rp| rp.production_store_rollouts.exists? }
    return PHASES[:review] if @release.release_platform_runs.any? { |rp| rp.active_production_release.present? }
    return PHASES[:stabilization] if @release.release_platform_runs.any? { |rp| rp.pre_prod_releases.exists? }
    PHASES[:kickoff]
  end

  private

  def new_change?
    @release.applied_commits != @release.all_commits
  end
end
