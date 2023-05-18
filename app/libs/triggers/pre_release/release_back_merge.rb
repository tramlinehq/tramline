class Triggers::PreRelease
  class ReleaseBackMerge
    def self.call(release, release_branch)
      # ReleaseBackMerge behaves the same as AlmostTrunk while making a new release
      Triggers::PreRelease::AlmostTrunk.call(release, release_branch)
    end
  end
end
