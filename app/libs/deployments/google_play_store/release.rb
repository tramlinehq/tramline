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

      def self.rollout_release!(deployment_run, rollout_value:, &blk)
        new(deployment_run).rollout_release!(rollout_value:, &blk)
      end

      def self.halt_release!(deployment_run, &blk)
        new(deployment_run).halt_release!(&blk)
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
        :google_play_store_integration?,
        :staged_rollout_config,
        :stamp_data,
        :promotable?,
        :release,
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
              run.upload_fail!

              reason =
                GooglePlayStoreIntegration::DISALLOWED_ERRORS_WITH_REASONS
                  .fetch(result.error.class, :upload_failed_reason_unknown)

              run.event_stamp!(reason:, kind: :error, data: stamp_data)
              elog(result.error)
            end
          end
        end
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
        release.with_lock do
          return unless run.rollout_started?
          yield provider.halt_release(deployment_channel, build_number, release_version, run.staged_rollout.last_rollout_percentage)
        end
      end

      def fully_release!
        release_with(rollout_value: Deployment::FULL_ROLLOUT_VALUE) do |result|
          if result.ok?
            run.complete!
          else
            run.fail_with_error(result.error)
          end
        end
      end

      def rollout!
        release_with(is_draft: true) do |result|
          if result.ok?
            run.create_staged_rollout!(config: staged_rollout_config)
          else
            run.fail_with_error(result.error)
          end
        end
      end

      # TODO: handle known errors gracefully and show to users
      def release_with(rollout_value: nil, is_draft: false)
        raise ArgumentError, "cannot have a rollout for a draft deployments" if is_draft && rollout_value.present?

        release.with_lock do
          return unless promotable?

          if is_draft
            yield provider.create_draft_release(deployment_channel, build_number, release_version)
          else
            yield provider.rollout_release(deployment_channel, build_number, release_version, rollout_value)
          end
        end
      end
    end
  end
end
