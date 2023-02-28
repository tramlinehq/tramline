# TODO:
# - error handle from applelink
# - disable increase/halt on staged rollout for non-controlled-rollouts
# - handle starting rollout (phased and full) -- TEST
# - poll to fetch live release status -- TEST
# - write controller action for submitting for review
# - add interface to trigger submitting for review
# - write controller action for rollout
# - add interface to trigger rollout
# - fix UI for app store release details in the builds section of live release page

# - validate correct build_number and version after preparing
# - validate status to be in PREPARE_FOR_SUBMISSION after preparing
# - see if this class can just be a concern
# - lock the release step from being run again if release is in submitted for review
# - add pause, resume and release to all users after rollout starts
# - add halt
# - add external_created, external_updated timestamps (or some version thereof) to external_release
# - add release_metadata model to train_run and attach it to app store release
# - add ui for release_metadata (notes, description, marketing url etc)
# - handle READY_FOR_REVIEW in applelink gracefully
class Deployments::AppStoreConnect::Release
  def self.kickoff!(deployment_run)
    new(deployment_run).kickoff!
  end

  def self.prepare_for_release!(deployment_run)
    new(deployment_run).prepare_for_release!
  end

  def self.submit_for_review!(deployment_run)
    new(deployment_run).submit_for_review!
  end

  def self.locate_external_release(deployment_run)
    new(deployment_run).locate_external_release
  end

  def self.to_test_flight!(deployment_run)
    new(deployment_run).to_test_flight!
  end

  def self.start_rollout!(deployment_run)
    new(deployment_run).start_rollout!
  end

  def initialize(deployment_run)
    @deployment_run = deployment_run
  end

  attr_reader :deployment_run
  alias_method :run, :deployment_run
  delegate :production_channel?, :provider, :deployment_channel, :build_number, :release_version, :staged_rollout?, :staged_rollout_config, to: :run

  def kickoff!
    return unless allowed?

    return Deployments::AppStoreConnect::PrepareForReleaseJob.perform_later(run.id) if production_channel?
    Deployments::AppStoreConnect::TestFlightReleaseJob.perform_later(run.id)
  end

  def prepare_for_release!
    return unless allowed? && production_channel?
    provider.prepare_release(build_number, release_version, staged_rollout?)
    run.prepare_release!
  end

  def submit_for_review!
    return unless allowed? && production_channel?
    run.submit! if provider.submit_release(build_number)
  end

  def start_rollout!
    return unless allowed? && production_channel?

    if provider.start_release(build_number)
      run.create_staged_rollout!(config: staged_rollout_config) if staged_rollout?
      Deployments::AppStoreConnect::FindLiveReleaseJob.perform_later(run.id)
    else
      run.dispatch_fail!
    end
  end

  def track_live_release_status(attempt: 1, wait: 1.second)
    release_info = provider.find_live_release
    if release_info.live?(build_number)
      return run.staged_rollout.update_stage(release_info.phased_release_stage) if staged_rollout?
      return run.complete!
    end

    Deployments::AppStoreConnect::FindLiveReleaseJob.set(wait: wait).perform_later(run.id, attempt:)
  end

  def to_test_flight!
    return unless allowed?
    provider.release_to_testflight(deployment_channel, build_number)
    run.submit!
  end

  def locate_external_release(attempt: 1, wait: 1.second)
    return unless allowed?
    Deployments::AppStoreConnect::UpdateExternalReleaseJob.set(wait: wait).perform_later(run.id, attempt:)
  end

  ExternalReleaseNotInTerminalState = Class.new(StandardError)

  def find_release
    return provider.find_release(build_number) if production_channel?
    provider.find_build(build_number)
  end

  def release_success
    return run.ready_to_release! if production_channel?
    run.complete!
  end

  def update_external_release
    return GitHub::Result.new unless allowed?

    release_info = find_release
    (run.external_release || run.build_external_release).update(release_info.attributes)

    GitHub::Result.new do
      if release_info.success?
        release_success
      elsif release_info.failed?
        run.dispatch_fail!
      else
        raise ExternalReleaseNotInTerminalState, "Retrying in some time..."
      end
    end
  end

  def allowed?
    run.app_store_integration? && run.release.on_track?
  end
end
