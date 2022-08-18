class Services::PostRelease
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  POST_RELEASE_HANDLERS = {
    "almost_trunk" => AlmostTrunk,
    "parallel_working" => ParallelBranches,
    "release_backmerge" => ReleaseBackMerge
  }

  def call
    POST_RELEASE_HANDLERS[train.branching_strategy].call(release)
  end

  def train
    release.train
  end

  private

  attr_reader :release
end
