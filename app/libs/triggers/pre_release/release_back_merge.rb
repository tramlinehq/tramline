class Triggers::PreRelease
  class ReleaseBackMerge
    def self.call(release, release_branch, bump_version: false)
      # ReleaseBackMerge behaves the same as AlmostTrunk while making a new release
      Triggers::PreRelease::AlmostTrunk.call(release, release_branch, bump_version:)
    end
  end
end
