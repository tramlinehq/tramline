module Tabbable
  include Memery
  extend ActiveSupport::Concern
  AUTO_SELECTABLES = [:internal_builds, :release_candidate, :app_submission, :rollout_to_users]

  included do
    helper_method :live_release_tab_configuration, :current_overall_status
  end

  def live_release!
    @release ||=
      Release
        .includes(
          :all_commits,
          train: [:app],
          release_platform_runs: [
            :internal_builds,
            :beta_releases,
            :production_store_rollouts,
            inflight_production_release: [store_submission: :store_rollout],
            active_production_release: [store_submission: :store_rollout],
            finished_production_release: [store_submission: :store_rollout],
            production_releases: [store_submission: [:store_rollout]],
            internal_releases: [:store_submissions, triggered_workflow_run: {build: [:artifact]}],
            release_platform: {app: [:integrations]}
          ]
        )
        .friendly
        .find(params[:id] || params[:release_id])
  end

  memoize def step_statuses
    @release.step_statuses
  end

  def active_tab
    tab = step_statuses[:statuses]
      .select { |step, status| AUTO_SELECTABLES.include?(step) && status == :ongoing }
      .keys
      .last

    paths.fetch(tab, paths[:overview])
  end

  memoize def paths
    {
      overview: overview_release_path(@release),
      changeset_tracking: changeset_tracking_release_path(@release),
      internal_builds: release_internal_builds_path(@release),
      regression_testing: regression_testing_release_path(@release),
      release_candidate: release_release_candidates_path(@release),
      soak_period: soak_release_path(@release),
      notes: release_metadata_edit_path(@release),
      screenshots: root_path,
      approvals: root_path,
      app_submission: release_store_submissions_path(@release),
      rollout_to_users: release_store_rollouts_path(@release)
    }
  end

  memoize def live_release_tab_configuration
    sections = {}

    sections[:kickoff] = {
      overview: Release::SECTIONS[:overview],
      changeset_tracking: Release::SECTIONS[:changeset_tracking]
    }
    sections[:kickoff][:overview][:path] = paths[:overview]
    sections[:kickoff][:overview][:icon] = "v2/gauge.svg"
    sections[:kickoff][:overview][:position] = 1
    sections[:kickoff][:overview][:status] = step_statuses[:statuses][:overview]
    sections[:kickoff][:changeset_tracking][:path] = paths[:changeset_tracking]
    sections[:kickoff][:changeset_tracking][:icon] = "v2/list_end.svg"
    sections[:kickoff][:changeset_tracking][:position] = 2
    sections[:kickoff][:changeset_tracking][:status] = step_statuses[:statuses][:changeset_tracking]

    sections[:stability] = {
      internal_builds: Release::SECTIONS[:internal_builds],
      regression_testing: Release::SECTIONS[:regression_testing],
      release_candidate: Release::SECTIONS[:release_candidate],
      soak_period: Release::SECTIONS[:soak_period]
    }
    sections[:stability][:internal_builds][:path] = paths[:internal_builds]
    sections[:stability][:internal_builds][:icon] = "v2/drill.svg"
    sections[:stability][:internal_builds][:position] = 3
    sections[:stability][:internal_builds][:status] = step_statuses[:statuses][:internal_builds]
    sections[:stability][:regression_testing][:path] = paths[:regression_testing]
    sections[:stability][:regression_testing][:icon] = "v2/tablet_smartphone.svg"
    sections[:stability][:regression_testing][:position] = 4
    sections[:stability][:regression_testing][:status] = step_statuses[:statuses][:regression_testing]
    sections[:stability][:regression_testing][:unavailable] = !demo_org?
    sections[:stability][:release_candidate][:path] = paths[:release_candidate]
    sections[:stability][:release_candidate][:icon] = "v2/gallery_horizontal_end.svg"
    sections[:stability][:release_candidate][:position] = 5
    sections[:stability][:release_candidate][:status] = step_statuses[:statuses][:release_candidate]
    sections[:stability][:soak_period][:path] = paths[:soak_period]
    sections[:stability][:soak_period][:icon] = "v2/alarm_clock.svg"
    sections[:stability][:soak_period][:position] = 6
    sections[:stability][:soak_period][:status] = step_statuses[:statuses][:soak_period]
    sections[:stability][:soak_period][:unavailable] = !demo_org?

    sections[:metadata] = {
      notes: Release::SECTIONS[:notes],
      screenshots: Release::SECTIONS[:screenshots]
    }
    sections[:metadata][:notes][:path] = paths[:notes]
    sections[:metadata][:notes][:icon] = "v2/text.svg"
    sections[:metadata][:notes][:position] = 7
    sections[:metadata][:notes][:status] = step_statuses[:statuses][:notes]
    sections[:metadata][:screenshots][:path] = paths[:screenshots]
    sections[:metadata][:screenshots][:icon] = "v2/wand.svg"
    sections[:metadata][:screenshots][:position] = 8
    sections[:metadata][:screenshots][:status] = step_statuses[:statuses][:screenshots]
    sections[:metadata][:screenshots][:unavailable] = true

    sections[:store_release] = {
      approvals: Release::SECTIONS[:approvals],
      app_submission: Release::SECTIONS[:app_submission],
      rollout_to_users: Release::SECTIONS[:rollout_to_users]
    }
    sections[:store_release][:approvals][:path] = paths[:approvals]
    sections[:store_release][:approvals][:icon] = "v2/list_checks.svg"
    sections[:store_release][:approvals][:position] = 9
    sections[:store_release][:approvals][:status] = step_statuses[:statuses][:approvals]
    sections[:store_release][:approvals][:unavailable] = true
    sections[:store_release][:app_submission][:path] = paths[:app_submission]
    sections[:store_release][:app_submission][:icon] = "v2/mail.svg"
    sections[:store_release][:app_submission][:position] = 10
    sections[:store_release][:app_submission][:status] = step_statuses[:statuses][:app_submission]
    sections[:store_release][:rollout_to_users][:path] = paths[:rollout_to_users]
    sections[:store_release][:rollout_to_users][:icon] = "v2/rocket.svg"
    sections[:store_release][:rollout_to_users][:position] = 11
    sections[:store_release][:rollout_to_users][:status] = step_statuses[:statuses][:rollout_to_users]

    sections
  end

  memoize def current_overall_status
    step_statuses[:current_overall_status]
  end
end
