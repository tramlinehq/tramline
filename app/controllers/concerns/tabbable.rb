module Tabbable
  def set_live_release_tab_configuration
    sections = {}
    step_statuses = @release.step_statuses

    sections[:kickoff] = {
      overview: Release::SECTIONS[:overview],
      changeset_tracking: Release::SECTIONS[:changeset_tracking]
    }
    sections[:kickoff][:overview][:path] = overview_release_path(@release)
    sections[:kickoff][:overview][:icon] = "v2/gauge.svg"
    sections[:kickoff][:overview][:position] = 1
    sections[:kickoff][:overview][:status] = step_statuses[:overview]
    sections[:kickoff][:changeset_tracking][:path] = change_queue_release_path(@release)
    sections[:kickoff][:changeset_tracking][:icon] = "v2/list_end.svg"
    sections[:kickoff][:changeset_tracking][:position] = 2
    sections[:kickoff][:changeset_tracking][:status] = step_statuses[:changeset_tracking]

    sections[:stability] = {
      internal_builds: Release::SECTIONS[:internal_builds],
      regression_testing: Release::SECTIONS[:regression_testing],
      release_candidate: Release::SECTIONS[:release_candidate],
      soak_period: Release::SECTIONS[:soak_period]
    }
    sections[:stability][:internal_builds][:path] = internal_builds_release_path(@release)
    sections[:stability][:internal_builds][:icon] = "v2/drill.svg"
    sections[:stability][:internal_builds][:position] = 3
    sections[:stability][:internal_builds][:status] = step_statuses[:internal_builds]
    sections[:stability][:regression_testing][:path] = regression_testing_release_path(@release)
    sections[:stability][:regression_testing][:icon] = "v2/tablet_smartphone.svg"
    sections[:stability][:regression_testing][:position] = 4
    sections[:stability][:regression_testing][:status] = step_statuses[:regression_testing]
    sections[:stability][:release_candidate][:path] = release_candidates_release_path(@release)
    sections[:stability][:release_candidate][:icon] = "v2/gallery_horizontal_end.svg"
    sections[:stability][:release_candidate][:position] = 5
    sections[:stability][:release_candidate][:status] = step_statuses[:release_candidate]
    sections[:stability][:soak_period][:path] = soak_release_path(@release)
    sections[:stability][:soak_period][:icon] = "v2/alarm_clock.svg"
    sections[:stability][:soak_period][:position] = 6
    sections[:stability][:soak_period][:status] = step_statuses[:soak_period]

    sections[:metadata] = {
      notes: Release::SECTIONS[:notes],
      screenshots: Release::SECTIONS[:screenshots]
    }
    sections[:metadata][:notes][:path] = release_metadata_edit_path(@release)
    sections[:metadata][:notes][:icon] = "v2/text.svg"
    sections[:metadata][:notes][:position] = 7
    sections[:metadata][:notes][:status] = step_statuses[:notes]
    sections[:metadata][:screenshots][:path] = root_path
    sections[:metadata][:screenshots][:icon] = "v2/wand.svg"
    sections[:metadata][:screenshots][:position] = 8
    sections[:metadata][:screenshots][:status] = step_statuses[:screenshots]
    sections[:metadata][:screenshots][:unavailable] = true

    sections[:release] = {
      approvals: Release::SECTIONS[:approvals],
      app_submission: Release::SECTIONS[:app_submission],
      rollout_to_users: Release::SECTIONS[:rollout_to_users]
    }
    sections[:release][:approvals][:path] = root_path
    sections[:release][:approvals][:icon] = "v2/list_checks.svg"
    sections[:release][:approvals][:position] = 9
    sections[:release][:approvals][:status] = step_statuses[:approvals]
    sections[:release][:approvals][:unavailable] = true
    sections[:release][:app_submission][:path] = store_submissions_release_path(@release)
    sections[:release][:app_submission][:icon] = "v2/mail.svg"
    sections[:release][:app_submission][:position] = 10
    sections[:release][:app_submission][:status] = step_statuses[:app_submission]
    sections[:release][:rollout_to_users][:path] = release_staged_rollout_edit_path(@release)
    sections[:release][:rollout_to_users][:icon] = "v2/rocket.svg"
    sections[:release][:rollout_to_users][:position] = 11
    sections[:release][:rollout_to_users][:status] = step_statuses[:rollout_to_users]

    @tab_configuration = sections
  end
end
