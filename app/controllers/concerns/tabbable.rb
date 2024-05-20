module Tabbable
  def set_live_release_tab_configuration
    @tab_configuration = {
      "kickoff" => [
        [1, "Overview", overview_release_path(@release), "v2/gauge.svg"],
        [2, "Changeset tracking", change_queue_release_path(@release), "v2/list_end.svg"]
      ],

      "stability" => [
        [2, "Internal builds", internal_builds_release_path(@release), "v2/drill.svg"],
        [2, "Regression testing", root_path, "v2/tablet_smartphone.svg"],
        [3, "Release candidate", root_path, "v2/gallery_horizontal_end.svg"],
        [4, "Beta soak", root_path, "v2/alarm_clock.svg"]
      ],

      "metadata" => [
        [2, "Notes", release_metadata_edit_path(@release), "v2/text.svg"],
        [2, "Screenshots", root_path, "v2/wand.svg"]
      ],

      "release" => [
        [2, "Approvals", root_path, "v2/list_checks.svg"],
        [2, "App submission", store_submissions_release_path(@release), "v2/mail.svg"],
        [3, "Store review", root_path, "v2/mail_search.svg"],
        [4, "Rollout to users", release_staged_rollout_edit_path(@release), "v2/rocket.svg"]
      ]
    }
  end
end
