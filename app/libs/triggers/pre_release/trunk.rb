class Triggers::PreRelease::Trunk
  def self.call(release, release_branch)
    new(release, release_branch).call
  end

  def initialize(release, release_branch)
    @release = release
    @release_branch = release_branch
  end

  def call
    GitHub::Result.new do
      latest_commit = @release.latest_commit_hash(sha_only: false)
      Coordinators::Signals.commits_have_landed!(@release, latest_commit, [])
    end
  end
end
