module ProductionReleases
  class CreateTagJob < ApplicationJob
    queue_as :high

    def perform(production_release_id)
      production_release = ProductionRelease.find(production_release_id)
      train = production_release.train
      release = production_release.release
      return unless train.tag_store_releases?
      commitish = production_release.commit.commit_hash

      if train.tag_store_releases_vcs_release?
        production_release.create_vcs_release!(commitish, release.release_diff)
      else
        production_release.create_tag!(commitish)
      end
    end
  end
end
