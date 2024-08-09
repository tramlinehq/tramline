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
    return unless @production_release.production?
    return unless @production_release.inflight?

    @production_release.with_lock do
      return unless @production_release.inflight?

      if @submission.attach_build(@build)
        @production_release.update!(build: @build)
        @submission.retrigger!
      end
    end
  end
end
