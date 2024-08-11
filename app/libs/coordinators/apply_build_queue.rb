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
      raise unless release.committable?
      raise unless build_queue.is_active?

      Coordinators::ApplyCommit.call(release, build_queue.head_commit)
      build_queue.update!(applied_at: Time.current, is_active: false)
      release.create_build_queue!
    end
  end

  attr_reader :build_queue, :release
end
