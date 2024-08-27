class Coordinators::UpdateBuildOnProduction
  def self.call(submission, build_id)
    new(submission, build_id).call
  end

  def initialize(submission, build_id)
    @submission = submission
    @production_release = @submission.parent_release
    @build = @submission.release_platform_run.rc_builds.find(build_id)
  end

  def call
    return unless production_release.actionable?
    return unless production_release.inflight?

    with_lock do
      return unless production_release.inflight?
      return if production_release.build == build

      if submission.attach_build(build)
        production_release.update!(build:)
        submission.retrigger!
      end
    end
  end

  attr_reader :submission, :production_release, :build
  delegate :with_lock, to: :production_release
end
