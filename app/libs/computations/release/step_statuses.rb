class Computations::Release::StepStatuses
  using RefinedArray
  STATUS = [:blocked, :unblocked, :ongoing, :success, :none, :hidden].zip_map_self
  PHASES = [:completed, :stopped, :kickoff, :stabilization, :approvals, :review, :rollout, :finishing].zip_map_self

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
        regression_testing: regression_testing_status,
        release_candidate: release_candidate_status,
        soak_period: demo? ? release_candidate_status : STATUS[:blocked],
        notes: notes_status,
        screenshots: STATUS[:blocked],
        approvals: approvals_status,
        app_submission: app_submission_status,
        rollout_to_users: rollout_to_users_status,
        wrap_up_automations: (wrap_up_automations_status unless any_platforms? { |rp| rp.conf.production_release? })
      }.compact,
      current_overall_status: current_overall_status
    }
  end

  def changeset_tracking_status
    return STATUS[:ongoing] if new_change?
    STATUS[:success]
  end

  def internal_builds_status
    return STATUS[:hidden] unless any_platforms? { |rp| rp.conf.internal_release? }
    return STATUS[:none] if all_platforms? { |rp| rp.latest_internal_release.blank? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_internal_release&.actionable? }
    STATUS[:success]
  end

  def regression_testing_status
    return STATUS[:hidden] unless any_platforms? { |rp| rp.conf.internal_release? }
    return internal_builds_status if demo?
    STATUS[:blocked]
  end

  def release_candidate_status
    return STATUS[:success] if finished?
    return STATUS[:none] if all_platforms? { |rp| rp.latest_beta_release.blank? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_beta_release&.actionable? }
    return STATUS[:ongoing] if any_platforms? { |rp| rp.latest_beta_release&.commit != rp.last_commit }
    STATUS[:success]
  end

  def notes_status
    return STATUS[:unblocked] if any_platforms? { |rp| rp.metadata_editable_v2? }
    STATUS[:success]
  end

  def approvals_status
    return STATUS[:hidden] unless @release.train.approvals_enabled?
    return STATUS[:none] if @release.approval_items.none?
    return STATUS[:ongoing] if @release.approvals_blocking?
    STATUS[:success]
  end

  def app_submission_status
    return STATUS[:blocked] if @release.approvals_blocking?
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

  def wrap_up_automations_status
    return STATUS[:success] if @release.finished?
    return STATUS[:blocked] if any_platforms? { |rp| rp.active? }
    STATUS[:ongoing]
  end

  def current_overall_status
    return PHASES[:completed] if finished?
    return PHASES[:stopped] if stopped? || stopped_after_partial_finish?
    return PHASES[:finishing] if Release::POST_RELEASE_STATES.include?(status)
    return PHASES[:rollout] if any_platforms? { |rp| rp.production_store_rollouts.present? }
    in_review = any_platforms? { |rp| rp.inflight_production_release.present? }
    return PHASES[:approvals] if @release.approvals_blocking? && in_review
    return PHASES[:review] if in_review
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

  def demo?
    @release.organization.demo?
  end

  delegate :finished?, :stopped?, :stopped_after_partial_finish?, :status, to: :@release
end
