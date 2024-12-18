module Deployments
  module AppStoreConnect
    class Release
      include Loggable

      ExternalReleaseNotInTerminalState = Class.new(StandardError)
      ReleaseNotFullyLive = Class.new(StandardError)
      PreparedVersionNotFoundError = Class.new(StandardError)

      RETRYABLE_FAILURE_REASONS = [:attachment_upload_in_progress]

      def self.kickoff!(deployment_run)
        new(deployment_run).kickoff!
      end

      def self.update_build_notes!(deployment_run)
        new(deployment_run).update_build_notes!
      end

      def self.update_external_release(deployment_run)
        new(deployment_run).update_external_release
      end

      def self.to_test_flight!(deployment_run)
        new(deployment_run).to_test_flight!
      end

      def self.prepare_for_release!(deployment_run, force: false)
        new(deployment_run).prepare_for_release!(force:)
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

      def self.pause_phased_release!(deployment_run)
        new(deployment_run).pause_phased_release!
      end

      def self.resume_phased_release!(deployment_run)
        new(deployment_run).resume_phased_release!
      end

      def self.halt_phased_release!(deployment_run)
        new(deployment_run).halt_phased_release!
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
        :test_flight_release?,
        :app_store_integration?,
        :app_store?,
        :staged_rollout_config,
        :release_metadatum,
        :internal_channel?,
        :deployment_notes,
        to: :run

      def kickoff!
        return run.start_prepare_release! if app_store_release?
        Deployments::AppStoreConnect::TestFlightReleaseJob.perform_async(run.id) if test_flight_release?
      end

      # NOTE: likely moves to internal/beta step
      def to_test_flight!
        return unless test_flight_release?

        Deployments::AppStoreConnect::UpdateBuildNotesJob.perform_async(run.id)

        return internal_release! if internal_channel?

        result = provider.release_to_testflight(deployment_channel, build_number)

        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        run.submit_for_review!
      end

      # NOTE: likely moves to internal/beta step
      def update_build_notes!
        provider.update_release_notes(build_number, deployment_notes)
      end

      # NOTE: moves to store submission
      def prepare_for_release!(force: false)
        return unless app_store_release?

        metadata = [{
          whats_new: release_metadatum.release_notes,
          promotional_text: release_metadatum.promo_text,
          locale: release_metadatum.locale
        }]

        result = provider.prepare_release(build_number, release_version, staged_rollout?, metadata, force)

        unless result.ok?
          case result.error.reason
          when :release_not_found then raise PreparedVersionNotFoundError
          when :release_already_exists then run.fail_prepare_release!(reason: result.error.reason)
          else run.fail_with_error(result.error)
          end

          return
        end

        unless valid_release?(result.value!)
          run.dispatch_fail!(reason: :invalid_release)
          return
        end

        create_or_update_external_release(result.value!)

        run.prepare_release!
        run.event_stamp!(reason: :inflight_release_replaced, kind: :notice, data: {version: release_version}) if force
      end

      # NOTE: moves to store submission
      def submit_for_review!
        return unless app_store_release?

        result = provider.submit_release(build_number, release_version)

        unless result.ok?
          return run.update(failure_reason: result.error.reason) if result.error.reason.in? RETRYABLE_FAILURE_REASONS
          return run.fail_with_error(result.error)
        end

        run.submit_for_review!
      end

      # NOTE: moves to store submission
      def update_external_release
        return unless run.step_run.active? && app_store_integration?

        result = find_release

        unless result.ok?
          elog(result.error)
          raise ExternalReleaseNotInTerminalState, "Retrying in some time..."
        end

        release_info = result.value!
        create_or_update_external_release(release_info)

        if release_info.success?
          return run.ready_to_release! if app_store?
          run.complete!
        elsif release_info.failed?
          run.dispatch_fail!(reason: :developer_rejected)
        elsif release_info.waiting_for_review? && run.review_failed?
          # A failed review was re-submitted or responded to outside Tramline
          run.submit_for_review!(resubmission: true)
        else
          run.fail_review! if release_info.review_failed? && !run.review_failed?
          raise ExternalReleaseNotInTerminalState, "Retrying in some time..."
        end
      end

      # NOTE: likely moves to rollout step
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

      # NOTE: likely moves to rollout step
      def track_live_release_status
        return unless app_store_release?

        result = provider.find_live_release

        unless result.ok?
          elog(result.error)
          raise ReleaseNotFullyLive, "Retrying in some time..."
        end

        release_info = result.value!
        create_or_update_external_release(release_info)

        if release_info.live?(build_number)
          return run.complete! unless staged_rollout?
          run.staged_rollout.update_stage(
            release_info.phased_release_stage,
            finish_rollout: release_info.phased_release_complete?
          )
          return if release_info.phased_release_complete?
        end

        raise ReleaseNotFullyLive, "Retrying in some time..."
      end

      # NOTE: likely moves to rollout step
      def complete_phased_release!
        return unless app_store_release?

        result = provider.complete_phased_release

        if result.ok?
          create_or_update_external_release(result.value!)
        else
          run.fail_with_error(result.error)
        end

        result
      end

      # NOTE: likely moves to rollout step
      def pause_phased_release!
        return unless app_store_release?

        result = provider.pause_phased_release

        if result.ok?
          release_info = result.value!
          create_or_update_external_release(release_info)
          run.staged_rollout.update_stage(
            release_info.phased_release_stage,
            finish_rollout: release_info.phased_release_complete?
          )
        end

        result
      end

      # NOTE: likely moves to rollout step
      def resume_phased_release!
        return unless app_store_release?

        result = provider.resume_phased_release

        if result.ok?
          release_info = result.value!
          create_or_update_external_release(release_info)
          run.staged_rollout.update_stage(
            release_info.phased_release_stage,
            finish_rollout: release_info.phased_release_complete?
          )
        end

        result
      end

      # NOTE: likely moves to rollout step
      def halt_phased_release!
        return unless app_store_release?

        provider.halt_phased_release
      end

      private

      # NOTE: likely moves to internal/beta step
      def internal_release!
        result = find_release
        unless result.ok?
          run.fail_with_error(result.error)
          return
        end

        release_info = result.value!
        create_or_update_external_release(release_info)
        run.complete!
      end

      def find_release
        return provider.find_release(build_number) if app_store?
        provider.find_build(build_number)
      end

      def create_or_update_external_release(release_info)
        (run.external_release || run.build_external_release).update(release_info.attributes)
      end

      def valid_release?(release_info)
        release_info.valid?(build_number, release_version, staged_rollout?)
      end
    end
  end
end
