class Queries::ReleaseSummary
  include Memery

  def self.all(**params)
    new(**params).all
  end

  def initialize(release:)
    @release = release
  end

  def all
    {
      review: {
        ios: {
          total_builds: 10,
          duration: ""
        },
        android: {
          total_builds: 10,
          duration: ""
        }
      },

      release: {
        ios: {
          total_builds: 10,
          duration: ""
        },
        android: {
          total_builds: 10,
          duration: ""
        }
      },

      store_versions: {
        ios: [{
          version: "",
          build_number: "",
          changelog: "",
          submitted: "",
          approved: "",
          staged_rollout_summary: StagedRollout.passports
        },
          {
            version: "",
            build_number: "",
            changelog: "",
            submitted: "",
            approved: "",
            staged_rollout_summary: StagedRollout.passports
          }],
        android: [
          {
            version: "",
            build_number: "",
            changelog: "",
            submitted: "",
            approved: "",
            staged_rollout_summary: StagedRollout.passports
          }
        ]
      },

      summary: {
        tag: {name: "", url: ""},
        duration: "",
        release_kickoff_date: "2023",
        release_end_date: "2023",
        total_backmerge_prs: 10,
        total_backmerge_failures: 5,
        total_release_commits: 20,
        versions: ["16.42", "16,43", "16.44"],
        final_version: "16.44"
      }
    }
  end
end
