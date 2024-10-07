module Tabbable
  include Memery
  extend ActiveSupport::Concern
  AUTO_SELECTABLE_LIVE_RELEASE_TABS = [:internal_builds, :release_candidate, :app_submission, :rollout_to_users]
  included { helper_method :live_release_tab_configuration, :live_release_overall_status }

  def set_train_config_tabs
    @tab_configuration = [
      [1, "Release Settings", edit_app_train_path(@app, @train), "v2/cog.svg"],
      ([2, "Steps", steps_app_train_path(@app, @train), "v2/route.svg"] unless v2?),
      ([2, "Android Flow Settings", edit_app_train_platform_submission_config_path(@app, @train, :android), "v2/logo_google_play_store_bw.svg"] if @app.cross_platform? && v2?),
      ([3, "iOS Flow Settings", edit_app_train_platform_submission_config_path(@app, @train, :ios), "v2/logo_app_store_bw.svg"] if @app.cross_platform? && v2?),
      ([2, "Submission Settings", edit_app_train_platform_submission_config_path(@app, @train, @app.platform), "v2/sliders.svg"] if v2? && !@app.cross_platform? && v2?),
      [4, "Notification Settings", app_train_notification_settings_path(@app, @train), "bell.svg"],
      [5, "Release Health Rules", rules_app_train_path(@app, @train), "v2/heart_pulse.svg"],
      [6, "Reldex Settings", edit_app_train_release_index_path(@app, @train), "v2/ruler.svg"]
    ].compact
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

  memoize def live_release_step_statuses
    @release.step_statuses
  end

  def live_release_active_tab
    tab = live_release_step_statuses[:statuses]
      .select { |step, status| AUTO_SELECTABLE_LIVE_RELEASE_TABS.include?(step) && status == :ongoing }
      .keys
      .last

    live_release_paths.fetch(tab, live_release_paths[:overview])
  end

  memoize def live_release_paths
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
      rollout_to_users: release_store_rollouts_path(@release),
      wrap_up_automations: wrap_up_automations_release_path(@release)
    }
  end

  memoize def live_release_tab_configuration
    sections = {}

    sections[:kickoff] = {
      overview: Release::SECTIONS[:overview],
      changeset_tracking: Release::SECTIONS[:changeset_tracking]
    }
    sections[:kickoff][:overview][:path] = live_release_paths[:overview]
    sections[:kickoff][:overview][:icon] = "v2/gauge.svg"
    sections[:kickoff][:overview][:position] = 1
    sections[:kickoff][:overview][:status] = live_release_step_statuses[:statuses][:overview]
    sections[:kickoff][:changeset_tracking][:path] = live_release_paths[:changeset_tracking]
    sections[:kickoff][:changeset_tracking][:icon] = "v2/list_end.svg"
    sections[:kickoff][:changeset_tracking][:position] = 2
    sections[:kickoff][:changeset_tracking][:status] = live_release_step_statuses[:statuses][:changeset_tracking]

    sections[:stability] = {
      internal_builds: Release::SECTIONS[:internal_builds],
      regression_testing: Release::SECTIONS[:regression_testing],
      release_candidate: Release::SECTIONS[:release_candidate],
      soak_period: Release::SECTIONS[:soak_period]
    }
    sections[:stability][:internal_builds][:path] = live_release_paths[:internal_builds]
    sections[:stability][:internal_builds][:icon] = "v2/drill.svg"
    sections[:stability][:internal_builds][:position] = 3
    sections[:stability][:internal_builds][:status] = live_release_step_statuses[:statuses][:internal_builds]
    sections[:stability][:regression_testing][:path] = live_release_paths[:regression_testing]
    sections[:stability][:regression_testing][:icon] = "v2/tablet_smartphone.svg"
    sections[:stability][:regression_testing][:position] = 4
    sections[:stability][:regression_testing][:status] = live_release_step_statuses[:statuses][:regression_testing]
    sections[:stability][:regression_testing][:unavailable] = !demo_org?
    sections[:stability][:release_candidate][:path] = live_release_paths[:release_candidate]
    sections[:stability][:release_candidate][:icon] = "v2/gallery_horizontal_end.svg"
    sections[:stability][:release_candidate][:position] = 5
    sections[:stability][:release_candidate][:status] = live_release_step_statuses[:statuses][:release_candidate]
    sections[:stability][:soak_period][:path] = live_release_paths[:soak_period]
    sections[:stability][:soak_period][:icon] = "v2/alarm_clock.svg"
    sections[:stability][:soak_period][:position] = 6
    sections[:stability][:soak_period][:status] = live_release_step_statuses[:statuses][:soak_period]
    sections[:stability][:soak_period][:unavailable] = !demo_org?

    sections[:metadata] = {
      notes: Release::SECTIONS[:notes],
      screenshots: Release::SECTIONS[:screenshots]
    }
    sections[:metadata][:notes][:path] = live_release_paths[:notes]
    sections[:metadata][:notes][:icon] = "v2/text.svg"
    sections[:metadata][:notes][:position] = 7
    sections[:metadata][:notes][:status] = live_release_step_statuses[:statuses][:notes]
    sections[:metadata][:screenshots][:path] = live_release_paths[:screenshots]
    sections[:metadata][:screenshots][:icon] = "v2/wand.svg"
    sections[:metadata][:screenshots][:position] = 8
    sections[:metadata][:screenshots][:status] = live_release_step_statuses[:statuses][:screenshots]
    sections[:metadata][:screenshots][:unavailable] = true

    if @release.release_platform_runs.any? { |rpr| rpr.conf.production_release? }
      sections[:store_release] = {
        approvals: Release::SECTIONS[:approvals],
        app_submission: Release::SECTIONS[:app_submission],
        rollout_to_users: Release::SECTIONS[:rollout_to_users]
      }
      sections[:store_release][:approvals][:path] = live_release_paths[:approvals]
      sections[:store_release][:approvals][:icon] = "v2/list_checks.svg"
      sections[:store_release][:approvals][:position] = 9
      sections[:store_release][:approvals][:status] = live_release_step_statuses[:statuses][:approvals]
      sections[:store_release][:approvals][:unavailable] = true
      sections[:store_release][:app_submission][:path] = live_release_paths[:app_submission]
      sections[:store_release][:app_submission][:icon] = "v2/mail.svg"
      sections[:store_release][:app_submission][:position] = 10
      sections[:store_release][:app_submission][:status] = live_release_step_statuses[:statuses][:app_submission]
      sections[:store_release][:rollout_to_users][:path] = live_release_paths[:rollout_to_users]
      sections[:store_release][:rollout_to_users][:icon] = "v2/rocket.svg"
      sections[:store_release][:rollout_to_users][:position] = 11
      sections[:store_release][:rollout_to_users][:status] = live_release_step_statuses[:statuses][:rollout_to_users]
    else
      sections[:wrap_up] = {
        wrap_up_automations: Release::SECTIONS[:wrap_up_automations]
      }
      sections[:wrap_up][:wrap_up_automations][:path] = live_release_paths[:wrap_up_automations]
      sections[:wrap_up][:wrap_up_automations][:icon] = "v2/robot.svg"
      sections[:wrap_up][:wrap_up_automations][:position] = 9
      sections[:wrap_up][:wrap_up_automations][:status] = live_release_step_statuses[:statuses][:wrap_up_automations]
    end

    sections
  end

  memoize def live_release_overall_status
    live_release_step_statuses[:current_overall_status]
  end
end
