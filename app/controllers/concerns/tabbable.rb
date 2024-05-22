module Tabbable
  def set_live_release_tab_configuration
    @tab_configuration = {
      "kickoff" => [
        [1, "Overview", overview_release_path(@release), "v2/gauge.svg"],
        [2, "Changeset tracking", change_queue_release_path(@release), "v2/list_end.svg"]
      ],

      "stability" => [
        [1, "Internal builds", internal_builds_release_path(@release), "v2/drill.svg"],
        [2, "Regression testing", regression_testing_release_path(@release), "v2/tablet_smartphone.svg"],
        [3, "Release candidate", root_path, "v2/gallery_horizontal_end.svg"],
        [4, "Soak period", soak_release_path(@release), "v2/alarm_clock.svg"]
      ],

      "metadata" => [
        [1, "Notes", release_metadata_edit_path(@release), "v2/text.svg"],
        [2, "Screenshots", root_path, "v2/wand.svg"]
      ],

      "release" => [
        [1, "Approvals", root_path, "v2/list_checks.svg"],
        [2, "App submission", store_submissions_release_path(@release), "v2/mail.svg"],
        [3, "Rollout to users", release_staged_rollout_edit_path(@release), "v2/rocket.svg"]
      ]
    }
  end
end
