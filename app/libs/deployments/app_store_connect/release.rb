class Deployments::AppStoreConnect::Release
  def self.kickoff!(deployment_run)
    new(deployment_run).kickoff!
  end

  def self.locate_external_build(deployment_run)
    new(deployment_run).locate_external_build
  end

  def self.to_test_flight!(deployment_run)
    new(deployment_run).to_test_flight!
  end

  def initialize(deployment_run)
    @deployment_run = deployment_run
  end

  attr_reader :deployment_run
  alias_method :run, :deployment_run
  delegate :production_channel?, :provider, :deployment_channel, :build_number, to: :run

  def prepare_for_release!
    return unless allowed? && production_channel?
    provider.prepare_release(build_number, release_version, staged_rollout?)
    run.prepare_release!
  end

  def kickoff!
    return unless allowed?

    if production_channel?
      Deployments::AppStoreConnect::PrepareForReleaseJob.perform_later(run.id)
    else
      Deployments::AppStoreConnect::TestFlightReleaseJob.perform_later(run.id)
    end
  end

  def to_test_flight!
    return unless allowed?
    provider.release_to_testflight(deployment_channel, build_number)
    run.submit!
  end

  def locate_external_build(attempt: 1, wait: 1.second)
    return unless allowed?
    Deployments::AppStoreConnect::UpdateExternalBuildJob.set(wait: wait).perform_later(run.id, attempt:)
  end

  ExternalBuildNotInTerminalState = Class.new(StandardError)

  def update_external_build
    return GitHub::Result.new unless allowed?

    build_info = provider.find_build(build_number)
    (run.external_build || run.build_external_build).update(build_info.attributes)

    GitHub::Result.new do
      if build_info.success?
        run.complete!
      elsif build_info.failed?
        run.dispatch_fail!
      else
        raise ExternalBuildNotInTerminalState, "Retrying in some time..."
      end
    end
  end

  def allowed?
    run.app_store_integration? && run.release.on_track?
  end
end
