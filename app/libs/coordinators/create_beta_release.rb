class Coordinators::CreateBetaRelease
  def self.call(build)
    new(build).call
  end

  def initialize(build)
    @build = build
  end

  attr_reader :build
  delegate :release_platform_run, to: :build
  delegate :release_platform, to: :release_platform_run
  delegate :transaction, to: ActiveRecord::Base

  def call
    transaction do
      beta_release = @release_platform_run.beta_releases.create!(config: release_platform_run.beta_release_config)

      if release_platform.separate_workflow_for_beta?
        beta_release.trigger_workflow!(release_platform.beta_workflow, build.commit)
      else
        beta_release.trigger_submissions!(build)
      end
    end
  end
end
