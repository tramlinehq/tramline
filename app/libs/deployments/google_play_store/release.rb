module Deployments
  module GooglePlayStore
    class Release
      include Loggable

      def self.kickoff!(deployment_run)
        new(deployment_run).kickoff!
      end

      def self.upload!(deployment_run)
        new(deployment_run).upload!
      end

      def self.start_release!(deployment_run)
        new(deployment_run).start_release!
      end

      def self.release_with(deployment_run, rollout_value:)
        new(deployment_run).release_with(rollout_value:)
      end

      def self.halt_release!(deployment_run)
        new(deployment_run).halt_release!
      end

      def self.release_to_all!(deployment_run)
        new(deployment_run).release_to_all!
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
        :release_metadata,
        :google_play_store_integration?,
        :staged_rollout_config,
        to: :run

      def kickoff!
        return run.upload! if run.step_run.similar_deployment_runs_for(run).any?(&:has_uploaded?)
        Deployments::GooglePlayStore::Upload.perform_later(run.id)
      end

      def upload!
        return unless google_play_store_integration?

        run.with_lock do
          return if run.uploaded?

          run.build_artifact.with_open do |file|
            result = provider.upload(file)
            if result.ok?
              run.upload!
            else
              run.fail_with_error(result.error)
            end
          end
        end

        run.notify!("Submitted for review!", :submit_for_review, run.notification_params)
      end

      def start_release!
        return unless google_play_store_integration?

        if staged_rollout?
          run.engage_release!
          rollout!
        else
          fully_release!
        end
      end

      def halt_release!
        return unless google_play_store_integration?
        return unless run.rollout_started?

        provider.halt_release(
          deployment_channel,
          build_number,
          release_version,
          run.staged_rollout.last_rollout_percentage
        )
      end

      def release_to_all!
        return unless google_play_store_integration?

        result = provider.rollout_release(
          deployment_channel,
          build_number,
          release_version,
          Deployment::FULL_ROLLOUT_VALUE,
          [release_metadata]
        )

        run.fail_with_error(result.error) unless result.ok?
        result
      end

      def release_with(rollout_value:)
        return unless google_play_store_integration?

        result = provider.rollout_release(
          deployment_channel,
          build_number,
          release_version,
          rollout_value,
          [release_metadata]
        )

        run.fail_with_error(result.error) unless result.ok?
        result
      end

      private

      def fully_release!
        result = provider.rollout_release(
          deployment_channel,
          build_number,
          release_version,
          Deployment::FULL_ROLLOUT_VALUE,
          [release_metadata]
        )

        if result.ok?
          run.complete!
        else
          run.fail_with_error(result.error)
        end
      end

      def rollout!
        result = provider.create_draft_release(
          deployment_channel,
          build_number,
          release_version,
          [release_metadata]
        )

        if result.ok?
          run.create_staged_rollout!(config: staged_rollout_config)
        else
          run.fail_with_error(result.error)
        end
      end
    end
  end
end
