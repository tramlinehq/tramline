class Computations::Release::StepStatuses
  using RefinedArray
  STATUS = [:blocked, :ongoing, :success, :none].zip_map_self
  PHASES = [:completed, :stopped, :kickoff, :stabilization, :review, :rollout, :finishing].zip_map_self

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
    return STATUS[:none] if all_platforms? { |rp| rp.internal_builds.none? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_internal_release&.actionable? }
    STATUS[:success]
  end

  def release_candidate_status
    return STATUS[:success] if finished?
    return STATUS[:none] if all_platforms? { |rp| rp.latest_beta_release.blank? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_beta_release.blank? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_beta_release&.actionable? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_beta_release&.commit != rp.last_commit }
    STATUS[:success]
  end

  def notes_status
    return STATUS[:ongoing] if any_platforms? { |rp| rp.metadata_editable_v2? }
    STATUS[:success]
  end

  def app_submission_status
    return STATUS[:blocked] if all_platforms? { |rp| rp.production_releases.none? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.inflight_production_release.present? }
    STATUS[:success]
  end

  def rollout_to_users_status
    return STATUS[:blocked] if all_platforms? { |rp| rp.production_store_rollouts.none? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.active_store_rollout&.present? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.inflight_store_rollout&.present? }
    STATUS[:success]
  end

  def current_overall_status
    return PHASES[:completed] if finished?
    return PHASES[:stopped] if stopped? || stopped_after_partial_finish?
    return PHASES[:finishing] if Release::POST_RELEASE_STATES.include?(status)
    return PHASES[:rollout] if any_platforms? { |rp| rp.production_store_rollouts.present? }
    return PHASES[:review] if any_platforms? { |rp| rp.active_production_release.present? }
    return PHASES[:stabilization] if any_platforms? { |rp| rp.pre_prod_releases.any? }
    PHASES[:kickoff]
  end

  private

  def new_change?
    @new_change ||= (@release.applied_commits != @release.all_commits)
  end

  def any_platforms?
    platform_runs.any? do |rp|
      yield(rp)
    end
  end

  def all_platforms?
    platform_runs.all? do |rp|
      yield(rp)
    end
  end

  def platform_runs
    @platform_runs ||= @release.release_platform_runs
  end

  delegate :finished?, :stopped?, :stopped_after_partial_finish?, :status, to: :@release
end
