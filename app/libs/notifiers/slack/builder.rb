module Notifiers
  module Slack
    class Builder
      # there are individual classes for each message so that any state, if necessary, can be encapsulated
      # think of them as view components
      RENDERERS = {
        deployment_finished: Renderers::DeploymentFinished,
        release_ended: Renderers::ReleaseEnded,
        release_stopped: Renderers::ReleaseStopped,
        release_started: Renderers::ReleaseStarted,
        step_started: Renderers::StepStarted,
        step_failed: Renderers::StepFailed,
        submit_for_review: Renderers::SubmitForReview,
        staged_rollout_updated: Renderers::StagedRolloutUpdated
      }

      class RendererNotFound < ArgumentError; end

      def self.build(type, **params)
        new(type, **params).build
      end

      def initialize(type, **params)
        @type = type
        @params = params
      end

      def build
        raise RendererNotFound unless RENDERERS.key?(type)
        RENDERERS[type].render_json(**params)
      end

      private

      attr_reader :type, :params
    end
  end
end
