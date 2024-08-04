class Coordinators::CreateBetaRelease
  def self.call(release_platform_run, build_id)
    new(release_platform_run, build_id).call
  end

  def initialize(release_platform_run, build_id)
    @release_platform_run = release_platform_run
    @build = release_platform_run.builds.find(build_id)
  end

  attr_reader :build, :release_platform_run
  delegate :transaction, to: BetaRelease

  def call
    transaction do
      beta_release = release_platform_run.beta_releases.create!(
        config: release_platform_run.conf.beta_release.value,
        commit: build.commit,
        previous: release_platform_run.latest_beta_release
      )

      if release_platform_run.conf.workflows.separate_rc_workflow?
        beta_release.trigger_workflow!(release_platform_run.conf.workflows.release_candidate_workflow, build.commit)
      else
        beta_release.trigger_submissions!(build)
      end
    end
  end
end
