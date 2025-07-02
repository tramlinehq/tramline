class Coordinators::PreReleaseJob < ApplicationJob
  RELEASE_HANDLERS = {
    "almost_trunk" => Coordinators::PreRelease::AlmostTrunk,
    "parallel_working" => Coordinators::PreRelease::ParallelBranches,
    "release_backmerge" => Coordinators::PreRelease::ReleaseBackMerge
  }

  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)
    release_branch = release.release_branch
    train = release.train
    branching_strategy = train.branching_strategy

    if release.hotfix_with_existing_branch?
      latest_commit = release.latest_commit_hash(sha_only: false)
      return Signal.commits_have_landed!(release, latest_commit, [])
    end

    begin
      release.start_pre_release_phase!
      RELEASE_HANDLERS[branching_strategy].call(release, release_branch).value!
    rescue Triggers::Errors => ex
      elog(ex, level: :warn)
      release.fail_pre_release_phase!
      release.event_stamp!(reason: :pre_release_failed, kind: :error, data: {error: ex.message})
    end
  end
end
