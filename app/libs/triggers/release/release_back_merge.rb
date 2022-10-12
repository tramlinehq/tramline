class Triggers::Release
  class ReleaseBackMerge
    def self.call(release, release_branch)
      # ReleaseBackMerge behaves the same as AlmostTrunk in Release phase
      Triggers::Release::AlmostTrunk.call(release, release_branch)
    end
  end
end
