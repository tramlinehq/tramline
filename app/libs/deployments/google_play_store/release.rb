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
        :release_metadatum,
        :google_play_store_integration?,
        :staged_rollout_config,
        :production_channel?,
        :deployment_notes,
        :one_percent_beta_release?,
        to: :run

      def kickoff!
        return run.upload! if run.step_run.similar_deployment_runs_for(run).any?(&:has_uploaded?)
        Deployments::GooglePlayStore::Upload.perform_later(run.id)
      end

      # NOTE: likely moves to internal/beta step
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
      end

      # NOTE: likely moves to rollout step
      def start_release!
        return unless google_play_store_integration?

        skip_release = run.step_run.deployment_restarted? && provider.build_present_in_channel?(deployment_channel, build_number)

        if staged_rollout?
          run.engage_release!
          create_draft_release!(skip_release:)
        else
          fully_release!(skip_release:)
        end
      end

      # NOTE: likely moves to rollout step
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

      # NOTE: likely moves to rollout step
      def release_to_all!
        return unless google_play_store_integration?

        result = provider.rollout_release(
          deployment_channel,
          build_number,
          release_version,
          Deployment::FULL_ROLLOUT_VALUE,
          release_notes
        )

        run.fail_with_error(result.error) unless result.ok?
        result
      end

      # NOTE: likely moves to rollout step
      def release_with(rollout_value:)
        return unless google_play_store_integration?

        result = provider.rollout_release(
          deployment_channel,
          build_number,
          release_version,
          rollout_value,
          release_notes
        )

        run.fail_with_error(result.error) unless result.ok?
        result
      end

      private

      # NOTE: likely moves to rollout step
      def fully_release!(skip_release: false)
        return run.complete! if skip_release

        rollout_value = one_percent_beta_release? ? BigDecimal("1") : Deployment::FULL_ROLLOUT_VALUE
        result = provider.rollout_release(
          deployment_channel,
          build_number,
          release_version,
          rollout_value,
          release_notes
        )

        if result.ok?
          run.complete!
        else
          run.fail_with_error(result.error)
        end
      end

      # NOTE: moves to submission step
      def create_draft_release!(skip_release: false)
        return run.create_staged_rollout!(config: staged_rollout_config) if skip_release

        result = provider.create_draft_release(
          deployment_channel,
          build_number,
          release_version,
          release_notes
        )

        if result.ok?
          run.create_staged_rollout!(config: staged_rollout_config)
        else
          run.fail_with_error(result.error)
        end
      end

      def release_notes
        return [] if deployment_notes.blank?

        [{
          language: release_metadatum.locale,
          text: deployment_notes
        }]
      end
    end
  end
end
