class Coordinators::ApplyBuildQueue
  def self.call(build_queue)
    new(build_queue).call
  end

  def initialize(build_queue)
    @build_queue = build_queue
    @release = build_queue.release
  end

  def call
    release.with_lock do
      raise "cannot apply a build queue to a locked release." unless release.committable?
      raise "cannot re-apply a build queue to a release!" unless build_queue.is_active?

      if build_queue.head_commit.present?
        Coordinators::ApplyCommit.call(release, build_queue.head_commit)
        release.create_vcs_release! if release.train.trunk?
      end

      build_queue.update!(applied_at: Time.current, is_active: false)
      release.create_build_queue!
    end
  end

  attr_reader :build_queue, :release
end
