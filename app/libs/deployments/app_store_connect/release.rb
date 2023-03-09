module Deployments
  module AppStoreConnect
    class Release
      include Loggable

      ExternalReleaseNotInTerminalState = Class.new(StandardError)
      ReleaseNotFullyLive = Class.new(StandardError)

      def self.kickoff!(deployment_run)
        new(deployment_run).kickoff!
      end

      def self.update_external_release(deployment_run)
        new(deployment_run).update_external_release
      end

      def self.to_test_flight!(deployment_run)
        new(deployment_run).to_test_flight!
      end

      def self.prepare_for_release!(deployment_run)
        new(deployment_run).prepare_for_release!
      end

      def self.submit_for_review!(deployment_run)
        new(deployment_run).submit_for_review!
      end

      def self.start_release!(deployment_run)
        new(deployment_run).start_release!
      end

      def self.track_live_release_status(deployment_run)
        new(deployment_run).track_live_release_status
      end

      def self.complete_phased_release!(deployment_run)
        new(deployment_run).complete_phased_release!
      end

      def initialize(deployment_run)
        @deployment_run = deployment_run
      end

      attr_reader :deployment_run
      alias_method :run, :deployment_run
      delegate :provider,
        :deployment_channel,
        :build_number,
        :release_version,
        :staged_rollout?,
        :app_store_release?,
        :app_store_integration?,
        :production_channel?,
        :staged_rollout_config,
        to: :run

      def kickoff!
        return unless run.release.on_track? && app_store_integration?

        return Deployments::AppStoreConnect::PrepareForReleaseJob.perform_later(run.id) if app_store_release?
        Deployments::AppStoreConnect::TestFlightReleaseJob.perform_later(run.id)
      end

      def to_test_flight!
        return unless run.release.on_track? && app_store_integration?
        return if production_channel?

        result = provider.release_to_testflight(deployment_channel, build_number)
        return run.fail_with_error(result.error) unless result.ok?

        run.submit_for_review!
      end

      def prepare_for_release!
        return unless app_store_release?

        result = provider.prepare_release(build_number, release_version, staged_rollout?)
        return run.fail_with_error(result.error) unless result.ok?

        run.prepare_release!
      end

      def submit_for_review!
        return unless app_store_release?

        result = provider.submit_release(build_number)

        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        run.submit_for_review!
      end

      def update_external_release
        return unless run.release.on_track? && app_store_integration?

        result = find_release
        return run.fail_with_error(result.error) unless result.ok?

        release_info = result.value!
        (run.external_release || run.build_external_release).update(release_info.attributes)

        if release_info.success?
          return run.ready_to_release! if production_channel?
          run.complete!
        elsif release_info.failed?
          run.dispatch_fail! # TODO: add a reason?
        else
          raise ExternalReleaseNotInTerminalState, "Retrying in some time..."
        end
      end

      def start_release!
        return unless app_store_release?

        run.engage_release!

        result = provider.start_release(build_number)

        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        run.create_staged_rollout!(config: staged_rollout_config) if staged_rollout?

        Deployments::AppStoreConnect::FindLiveReleaseJob.perform_async(run.id)
      end

      def track_live_release_status
        return unless app_store_release?

        result = provider.find_live_release
        unless result.ok?
          return run.fail_with_error(result.error)
        end

        release_info = result.value!
        run.external_release.update(release_info.attributes)

        if release_info.live?(build_number)
          return run.complete! unless staged_rollout?
          run.staged_rollout.update_stage(release_info.phased_release_stage)
          return if release_info.phased_release_complete?
        end

        raise ReleaseNotFullyLive, "Retrying in some time..."
      end

      def complete_phased_release!
        return unless app_store_release?
        return unless run.rolloutable?

        result = provider.complete_phased_release

        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        track_live_release_status # TODO: should not be sync?
      end

      private

      def find_release
        return provider.find_release(build_number) if production_channel?
        provider.find_build(build_number)
      end
    end
  end
end
