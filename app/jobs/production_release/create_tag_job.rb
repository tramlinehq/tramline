module ProductionRelease
  class CreateTagJob < ApplicationJob
    queue_as :high

    def perform(platform_run_id, commit_id)
      commit = Commit.find(commit_id)
      release_platform_run = ReleasePlatformRun.find(platform_run_id)
      release = release_platform_run.release
      train = release_platform_run.train
      return unless train.tag_store_releases?
      commitish = commit.commit_hash
      tag_name = tag_name(train, release_platform_run)

      if train.tag_store_releases_vcs_release?
        release_platform_run.create_vcs_release!(commitish, release.release_diff)
      else
        release_platform_run.create_tag!(commitish, tag_name)
      end
    end
  end
end
