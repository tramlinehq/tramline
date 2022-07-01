class Services::PostRelease
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
    @train = release.train
  end

  POST_RELEASE_HANDLERS = {
    "alomost_trunk" => AlmostTrunk,
    "release_backmerge" => ReleaseBackMerge,
    "parallel_working" => ParallelBranches
  }

  def call
    POST_RELEASE_HANDLERS[@train.branching_strategy].call(@release)
  end
end
